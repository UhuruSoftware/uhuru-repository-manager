#!/bin/bash

action=$1
tarball=$2
destination=$3

function checkarchive()
{
# check if the archive is compressed with gzip or bzip2
extract_args="unknown"

# change permissions, make it readable just for the user&group
chmod 640 ${tarball}

[ ! -z "`file ${tarball}|grep gzip`" ] &&
  {
  extract_args="zxvf"
  list_args="ztvf"
  }

[ ! -z "`file ${tarball}|grep bzip`" ] &&
  {
  extract_args="jxvf"
  list_args="jtvf"
  }

# if its neither gzip nor bzip2, exit
[ "$extract_args" = "unknown" ] &&
  {
  echo "Unknown archive type"
  exit 1
  }
 
}

function add()
{
[ ! -d ${destination}/ubuntu/stable/binary-amd64 ] && mkdir -p ${destination}/ubuntu/stable/binary-amd64

  tar ${extract_args} $tarball -C ${destination}/ubuntu/stable/binary-amd64
  
  regenerate
  
  chown -R root.`basename ${destination}` ${destination}
  chmod 0750 ${destination}
}

function delete()
{
for file in `tar ${list_args} ${tarball} | awk '{print $6}'|grep "^uhuru-"`;
  do
  rm -f ${destination}/ubuntu/stable/binary-amd64/${file}
  done
  
  regenerate
}

function regenerate()
{
cd ${destination}
dpkg-scanpackages ./ubuntu/stable/binary-amd64 /dev/null | sed s,./ubuntu/stable/binary-amd64,./dists/ubuntu/stable/binary-amd64/,g | gzip -9c > ${destination}/ubuntu/stable/binary-amd64/Packages.gz
}

checkarchive  
$action
