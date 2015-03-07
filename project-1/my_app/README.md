# Overview

This is the meat-and-bones of Project #1. The the README in the parent directory 
for a better overview.

# Testing Notes

## Starting Trinidad:

<code>JAVA_OPTS="-Djava.awt.headless=true -Xms756m -Xmx756m -Xss128m -Xmn512m -XX:PermSize=512m -XX:MaxPermSize=512m -XX:NewRatio=3 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+CMSClassUnloadingEnabled -XX:+CMSClassUnloadingEnabled" trinidad --threadsafe</code>

## Simple load test:

i=0; while [ $i -lt 300 ]; do echo $i; i=$(($i+1)); curl --form "theFile=@my-file.txt;filename=desired-filename.txt" --form userID=1 --form param2=value2 http://127.0.0.1:3000/ece1779/servlet/FileUpload ; done
