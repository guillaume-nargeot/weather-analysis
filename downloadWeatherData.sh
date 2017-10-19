#!/bin/bash

# cleanup and setup folders
rm -rf step*
mkdir step1 step2 step3 step4

# retrieve holiday calendar
FIRST_YEAR=2016
THIS_YEAR=`date +"%Y"`
YEARS=`seq $FIRST_YEAR $THIS_YEAR`
for year in $YEARS; do
    # TODO if the file for this year exists, check it contains $THIS_YEAR/12/31
    if [[ ! -f "step1/tokyo-$year-holiday.csv" ]]; then
        curl -s -G \
            -d start_year=$year -d end_year=$year \
            -d id=3 -d start_mon=1 -d end_mon=12 -d year_style=normal \
            -d month_style=ja -d wday_style=en -d format=csv -d holiday_only=1 \
            -d zero_padding=1 \
            -H 'Accept-Encoding: gzip, deflate' --compressed \
            'http://calendar-service.net/cal' \
            -o step1/tokyo-$year-holiday.csv
        sleep 1
    fi
done

# retrieve session id for japan meteorological agency website
SID=$(curl -s http://www.data.jma.go.jp/gmd/risk/obsdl/index.php | \
          grep "input type=.hidden. id..sid" | \
          cut -d\" -f6)

# retrieve rainfall data
for year in $YEARS; do
    if [[ ! -f "step1/tokyo-$year-hourly-rainfall.csv" ]]; then
        curl -s 'http://www.data.jma.go.jp/gmd/risk/obsdl/show/table' \
                -H 'Accept-Encoding: gzip, deflate' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Cache-Control: max-age=0' -H 'Connection: keep-alive' \
                --data "stationNumList=%5B%22s47662%22%5D&aggrgPeriod=9&elementNumList=%5B%5B%22101%22%2C%22%22%5D%5D&interAnnualFlag=1&ymdList=%5B%22$year%22%2C%22$year%22%2C%221%22%2C%2212%22%2C%221%22%2C%2231%22%5D&optionNumList=%5B%5D&downloadFlag=true&rmkFlag=1&disconnectFlag=1&youbiFlag=0&fukenFlag=0&kijiFlag=0&huukouFlag=0&csvFlag=1&jikantaiFlag=0&jikantaiList=%5B1%2C24%5D&ymdLiteral=1&PHPSESSID=$SID" --compressed \
                -o step1/tokyo-$year-hourly-rainfall.csv
        sleep 1
    fi
done

# retrieve illumination data (only diff with rainfall is 401 instead of 101 inside the value of elementNumList)
for year in $YEARS; do
    if [[ ! -f "step1/tokyo-$year-hourly-illumination.csv" ]]; then
        curl -s 'http://www.data.jma.go.jp/gmd/risk/obsdl/show/table' \
                -H 'Accept-Encoding: gzip, deflate' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Cache-Control: max-age=0' -H 'Connection: keep-alive' \
                --data "stationNumList=%5B%22s47662%22%5D&aggrgPeriod=9&elementNumList=%5B%5B%22401%22%2C%22%22%5D%5D&interAnnualFlag=1&ymdList=%5B%22$year%22%2C%22$year%22%2C%221%22%2C%2212%22%2C%221%22%2C%2231%22%5D&optionNumList=%5B%5D&downloadFlag=true&rmkFlag=1&disconnectFlag=1&youbiFlag=0&fukenFlag=0&kijiFlag=0&huukouFlag=0&csvFlag=1&jikantaiFlag=0&jikantaiList=%5B1%2C24%5D&ymdLiteral=1&PHPSESSID=$SID" --compressed \
                -o step1/tokyo-$year-hourly-illumination.csv
        sleep 1
    fi
done

# retrieve illumination data (only diff with rainfall is 201 instead of 101 inside the value of elementNumList)
for year in $YEARS; do
    if [[ ! -f "" ]]; then
        curl -s 'http://www.data.jma.go.jp/gmd/risk/obsdl/show/table' \
                -H 'Accept-Encoding: gzip, deflate' -H 'Content-Type: application/x-www-form-urlencoded' -H 'Cache-Control: max-age=0' -H 'Connection: keep-alive' \
                --data "stationNumList=%5B%22s47662%22%5D&aggrgPeriod=9&elementNumList=%5B%5B%22201%22%2C%22%22%5D%5D&interAnnualFlag=1&ymdList=%5B%22$year%22%2C%22$year%22%2C%221%22%2C%2212%22%2C%221%22%2C%2231%22%5D&optionNumList=%5B%5D&downloadFlag=true&rmkFlag=1&disconnectFlag=1&youbiFlag=0&fukenFlag=0&kijiFlag=0&huukouFlag=0&csvFlag=1&jikantaiFlag=0&jikantaiList=%5B1%2C24%5D&ymdLiteral=1&PHPSESSID=$SID" --compressed \
                -o step1/tokyo-$year-hourly-temperature.csv
        sleep 1
    fi
done

# convert to UTF-8
cd step1
for i in tokyo-*-hourly-*.csv; do iconv -f SHIFT-JIS -t UTF-8 $i | tail -n +4 > ../step2/$i; done
for i in tokyo-*-holiday.csv; do iconv -f EUC-JP -t UTF-8 $i > ../step2/$i; done
dos2unix -q tokyo-*.csv
cd ..

# convert dates to iso format
cd step2
for i in tokyo-*-hourly-*.csv; do
    cat $i | \
        sed s'/^\(....\)\/\([0-9]\)\//\1\/0\2\//' | \
        sed s'/^\(.......\)\/\([0-9]\) /\1\/0\2 /' | \
        sed s'/^\([^ ]*\) \([0-9]\):/\1T0\2:/' | \
        sed s'/^\([^ ]*\) /\1T/' | \
	sed s'/^\([^,]\+\),/\1.000,/'> ../step3/$i
done
for i in tokyo-*-holiday.csv; do
    cat $i | \
        sed s'/,/\//' | sed s'/,/\//' | \
        grep -v -e ,Sat, -e ,Sun, | \
        cut -d, -f1,4 | sed s'/,[MTWF].*/,1/' > ../step3/$i
done
cd ..

# join files
cd step3
for i in tokyo-*-hourly-temperature.csv; do
    YEAR=$(echo $i | grep -o "\b\d\{4\}\b")
    join -t, --nocheck-order tokyo-$YEAR-hourly-temperature.csv tokyo-$YEAR-hourly-rainfall.csv | \
        join -t, --nocheck-order tokyo-$YEAR-hourly-illumination.csv - | \
        tr ' ' ',' | \
        # TODO add comma to split first field of first line and leading comma to second line
        sed s'///g' > ../step4/tokyo-$YEAR-hourly-stats.csv
    FIRST_FIELD=$(head -1 $i | cut -d, -f1)
    echo "$FIRST_FIELD,Holiday" > ../step4/tokyo-$YEAR-holiday.csv
    echo "," >> ../step4/tokyo-$YEAR-holiday.csv
    tail -n +2 tokyo-$YEAR-holiday.csv >> ../step4/tokyo-$YEAR-holiday.csv
done
cd ..
