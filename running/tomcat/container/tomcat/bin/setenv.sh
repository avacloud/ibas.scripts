# memory overflow than exit
export JAVA_OPTS="-XX:+ExitOnOutOfMemoryError"
# custom jdk
if [ -d "${CATALINA_HOME}/jdk" ]; then
    export JAVA_HOME="${CATALINA_HOME}/jdk"
    export JRE_HOME="${CATALINA_HOME}/jdk"
fi