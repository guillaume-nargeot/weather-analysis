#!/bin/bash

# cleanup and setup folders
rm -rf step*
mkdir step1 step2 step3 step4
unzip -q tokyo-weather-data.zip -d step1/

# convert to UTF-8
cd step1
for i in tokyo-*-hourly-*.csv; do iconv -f SHIFT-JIS -t UTF-8 $i | tail -n +4 > ../step2/$i; done
for i in tokyo-*-holiday.csv; do iconv -f EUC-JP -t UTF-8 $i > ../step2/$i; done
dos2unix -q tokyo-*.csv
cd ..

# convert dates
cd step2
for i in tokyo-*-hourly-*.csv; do
    cat $i | \
	sed s'/^\(....\)\/\([0-9]\)\//\1\/0\2\//' | \
	sed s'/^\(.......\)\/\([0-9]\) /\1\/0\2 /' | \
	sed s'/^\([^ ]*\) \([0-9]\):/\1 0\2:/' > ../step3/$i
done
cd ..

# join files
cd step3
for i in tokyo-*-hourly-temperature.csv; do
    # 
    # 
    YEAR=$(echo $i | grep -o "\b[0-9]\{4\}\b")
    join -t, --nocheck-order tokyo-$YEAR-hourly-temperature.csv tokyo-$YEAR-hourly-rainfall.csv | \
        join -t, --nocheck-order tokyo-$YEAR-hourly-illumination.csv - | \
	sed s'///g' > ../step4/tokyo-$YEAR-hourly-stats.csv
done
cd ..
