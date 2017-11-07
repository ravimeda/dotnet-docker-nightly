import jobs.generation.Utilities

def project = GithubProject
def branch = GithubBranchName
def isPR = true
def platformList = ['Ubuntu16.04:Debian', 'Windows_2016:NanoServer', 'Windows_2016:NanoServer-1709']

platformList.each { platform ->
    def(hostOS, containerOS) = platform.tokenize(':')
    def machineLabel = (hostOS == 'Windows_2016') ? 'latest-docker' : 'latest-or-auto-docker'
    def versionList = (hostOS == 'Windows_2016') ? ['1.', '2.0', '2.1'] : ['1.', '2.']
    if (containerOS == 'NanoServer-1709') {
        versionList = ['2.0', '2.1']
    }

    versionList.each { version ->
        def newJobName = Utilities.getFullJobName(project, "${containerOS}_${version}", isPR)
        def versionFilter = "${version}*"

        def newJob = job(newJobName) {
            steps {
                if (hostOS == 'Windows_2016') {
                    if (versionFilter.contains("2.")) {
                        versionFilter.concat("/nanoserver")
                        if (containerOS == 'NanoServer-1709') {
                            versionFilter.concat("-1709");
                        }
                        versionFilter.concat("/*")
                    }
                    batchFile("powershell -NoProfile -Command .\\build-and-test.ps1 -Filter \"${versionFilter}\"")
                }
                else {
                    shell("docker build --rm -t testrunner -f ./test/Dockerfile.linux.testrunner . && docker run -v /var/run/docker.sock:/var/run/docker.sock testrunner powershell -File build-and-test.ps1 -Filter \"${versionFilter}\"")
                }
            }
        }

        if (containerOS == 'NanoServer-1709') {
            newJob.with {label('windows.10.amd64.serverrs3.open')}
        }
        else {
            Utilities.setMachineAffinity(newJob, hostOS, machineLabel)
        }

        Utilities.standardJobSetup(newJob, project, isPR, "*/${branch}")
        Utilities.addGithubPRTriggerForBranch(newJob, branch, "${containerOS} - ${version} Dockerfiles")
    }
}
