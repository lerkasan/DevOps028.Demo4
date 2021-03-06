#!groovy

podTemplate(
        label: 'slave',
        cloud: 'jenkins',
        name: 'jenkins-slave',
        namespace: 'jenkins',
        containers: [
                containerTemplate(
                        name: 'jenkins-slave-mvn',
                        image: 'registry.lerkasan.de:5000/jenkins-slave-mvn',
                        ttyEnabled: true,
                        privileged: false,
                        alwaysPullImage: false,
                        workingDir: '/home/jenkins',
                        command: 'cat'
                ),
                containerTemplate(
                        name: 'jenkins-slave-docker',
                        image: 'registry.lerkasan.de:5000/jenkins-slave-docker',
                        ttyEnabled: true,
                        privileged: true,
                        alwaysPullImage: false,
                        workingDir: '/home/jenkins',
                        command: 'cat'
                ),
                containerTemplate(
                        name: 'jenkins-slave-kops',
                        image: 'registry.lerkasan.de:5000/jenkins-slave-kops',
                        ttyEnabled: true,
                        privileged: false,
                        alwaysPullImage: false,
                        workingDir: '/home/jenkins',
                        command: 'cat'
                )
        ],
        volumes: [
                hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')
        ]
) {
    node('slave') {
        currentBuild.result = "SUCCESS"
        try {
            timestamps {
                stage("Test and build jar") {
                    git url: 'https://github.com/lerkasan/DevOps028.Demo4.git'
                    container('jenkins-slave-mvn') {
                        echo "Testing project ..."
                        sh "mvn clean test"
                        echo "Building jar ..."
                        sh "mvn clean package"
                        archiveArtifacts artifacts: 'target/*.jar', onlyIfSuccessful: true
                    }
                }
                stage("Build and push samsara webapp image") {
                    container('jenkins-slave-docker') {
                        echo "Building and pushing samsara webapp image ..."
                        def REGISTRY_URL = "registry.lerkasan.de:5000"
                        def REGISTRY_LOGIN = "lerkasan"
                        def REGISTRY_PASSWORD = "J*t47X8#RmF2"
                        def ARTIFACT_FILENAME = sh(
                                script: "ls ${WORKSPACE}/target | grep jar | grep -v original",
                                returnStdout: true
                        ).trim()
                        sh "cp ${WORKSPACE}/target/${ARTIFACT_FILENAME} ."
                        sh "docker login ${REGISTRY_URL} -u ${REGISTRY_LOGIN} -p ${REGISTRY_PASSWORD}"
                        sh "docker build -t samsara-webapp:latest -t samsara-webapp:build${env.BUILD_NUMBER} --build-arg ARTIFACT_FILENAME=${ARTIFACT_FILENAME} --pull ."
                        sh "docker tag samsara-webapp:latest ${REGISTRY_URL}/samsara-webapp:latest"
                        sh "docker tag samsara-webapp:build${env.BUILD_NUMBER} ${REGISTRY_URL}/samsara-webapp:build${env.BUILD_NUMBER}"
                        sh "docker push ${REGISTRY_URL}/samsara-webapp:latest"
                        sh "docker push ${REGISTRY_URL}/samsara-webapp:build${env.BUILD_NUMBER}"
                        sh "docker rmi -f `docker images -q` | true"
                    }
                }
                stage("Deploy webapp") {
                    container('jenkins-slave-kops') {
                        def NAME = "samsara"
                        def CLUSTER_NAME = "${NAME}.lerkasan.de"
                        def KOPS_STATE_STORE = "s3://${NAME}-cluster-state"
                        sh "aws s3 cp ${KOPS_STATE_STORE}/kube-config ~/.kube/config"
                        // Adding current datetime annotation patch forces kubernetes to do rolling-update of samsara and pull latest image from registry
                        sh 'kubectl patch deployment samsara -p "{\\"spec\\":{\\"template\\":{\\"metadata\\":{\\"annotations\\":{\\"date\\":\\"`date +\'%s\'`\\"}}}}}" --namespace=samsara'
                        sh "kops rolling-update cluster ${CLUSTER_NAME} --state ${KOPS_STATE_STORE} --yes"
                        sleep time: 120, unit: 'SECONDS'

                    }
                }
                stage("Check webapp") {
                    echo "Checking connectivity to webapp load balancer ..."
                    def WEBAPP_HOST = "samsara.lerkasan.de"
                    echo "URL is ${WEBAPP_HOST}/login"
                    def response = httpRequest url: "http://${WEBAPP_HOST}/login", httpMode: 'GET', timeout: 60, consoleLogResponseBody: true
                    println("Webapp HTTP_RESPONSE_CODE = " + response.getStatus())
                    println("Webapp endpoint: ${WEBAPP_HOST}")

                    emailext body: '${BUILD_LOG_REGEX, regex="Webapp endpoint", showTruncatedLines=false}',
                            subject: 'Web application Samsara was deployed',
                            to: 'lerkasan@gmail.com'
                }
            }
        }
        catch (err) {

            currentBuild.result = "FAILURE"

            emailext attachLog: true,
                    body: 'Samsara project build error is here: ${env.BUILD_URL}. Build log is attached.',
                    subject: 'Web application Samsara deploy failed',
                    to: 'lerkasan@gmail.com'

            throw err
        }
    }
}