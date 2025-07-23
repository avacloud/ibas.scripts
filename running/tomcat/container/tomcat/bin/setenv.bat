rem 内存溢出后最退出，以便重启服务
set JAVA_OPTS=-XX:+ExitOnOutOfMemoryError
rem 指定编码方式
set JAVA_OPTS="%JAVA_OPTS% -Dfile.encoding=UTF-8"