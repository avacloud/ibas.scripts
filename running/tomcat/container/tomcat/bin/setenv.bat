rem memory overflow than exit
set JAVA_OPTS=-XX:+ExitOnOutOfMemoryError
rem default encoding
set JAVA_OPTS=%JAVA_OPTS% -Dfile.encoding=UTF-8
rem custom jdk
if exist "%CATALINA_HOME%\jdk" (
    set "JAVA_HOME=%CATALINA_HOME%\jdk"
    set "JRE_HOME=%CATALINA_HOME%\jdk"
)