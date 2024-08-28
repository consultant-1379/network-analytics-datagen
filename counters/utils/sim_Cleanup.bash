#!/bin/bash
date;
cd /eniq/data/pmdata;
for i in `ls  | grep eniq` ;
do

cd $i;

count=0;
count=$(find . -name 'A20*.xml'  -mtime +0.5 -exec ls {} \; | wc -l) ;
echo "file count $count";

echo "Cleaning files that are older than a day under";
echo $i
find . -name 'A20*.xml'  -mtime +0.5 -exec rm -f {} \;
cd .. ;

done

