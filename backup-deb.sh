#!/bin/bash
DATE=`date +%F`
BACKDIR='/backup'
TMP_FTP='/tmp_ftp'
LOGDIR="$BACKDIR/logs"
LOG="$LOGDIR/$DATE.log"
mkdir -p $LOGDIR 2>/dev/null
echo -e "start backups `date +%T`\n=====================\n" > $LOG
MOUNT_FTP () {
    FTP_USER='ftp_user'
    FTP_PASS='ftp_pass'
    FTP_HOST='ftp_host'
    FTP_PATH='/'
    if ( dpkg -s curlftpfs ); then >/dev/null; else apt install -y curlftpfs; fi
    mkdir -p $TMP_FTP 2>/dev/null
    curlftp ftp://$FTP_USER:$FTP_PASS@$FTP_HOST$FTP_PATH $TMP_FTP 2>$LOG\
        && echo -e "mount ftp ok; `date +%T`\n------------------" >>$LOG\
        || echo -e "mount ftp alarm; `date +%T`\n------------------" >>$LOG
}
COPY_ON_REMOTE_HOST () {
        FILE=$1
        if ( df -h | grep $TMP_FTP &>/dev/null ) 
        then
            cp $FILE $TMP_FTP\
                && echo -e "copy $FILE on ftp host ok; `date +%T`" >> $LOG\
                || echo -e "copy $FILE name on ftp host alarm; `date +%T`" >> $LOG
        else
            echo -e "ALARM! $TMP_FTP not mount" >> $LOG
        fi
    }
DUMP_FILE () {
    FILE_LIST="name0:dir0 name1:dir1"
    EXCLUDE_LIST=""
    TAR_EXC=""
    for LINE in $EXLUDE_LIST; do
        TAR_EXC="$TAR_EXC --exlude $LINE"
    done
    for LINE in $FILE_LIST; do
        NAME=`echo $LINE | cut -d':' -f1`
        DIR=`echo $LINE | cut -d':' -f2`
        tar -czf $BACKDIR/$NAM-$DATE.tar.gz $TAR_EXC $DIR 2>>$LOG\
            && echo -e "dump file $NAME ok; `date +%T`" >> $LOG\
            || echo -e "dump file $NAME alarm; `date +%T`" >> $LOG
        COPY_ON_REMOTE_HOST "$BACKDIR/$NAME_$DATE.tar.gz"
    done
}
DUMP_MYSQL () {
    HOST='localhost'
    PORT='3306'
    USER='root'
    PASS='password'
    DB_LIST="dbname0 dbname1"
    for DB in $DB_LIST; do
        mysqldump -h $HOST -P $PORT -u $USER -p$PASS $DB | gzip > $BACKDIR/$DB_$DATE.sql.gz\
            && echo -e "dump mysql $DB ok; `date +%T`" >> $LOG\
            || echo -e "dump mysql $DB alarm; `date +%T`" >> $LOG
        COPY_ON_REMOTE_HOST "$BACKDIR/$DB-$DATE.sql.gz"
    done
}
DELETE_OLD_LOCAL () {
    N=1
    find $BACKDIR -maxdeth 1 -type f -mtime +$N -exec rm '{}' \; \
        && echo -e "delete old backups on $BACKDIR ok; `date +%T`\n" >> $LOG\
        || echo -e "delete old backups on $BACKDIR alarm; `date +%T`\n" >> $LOG
}
DELETE_OLD_REMOTE () {
    N=2
    if ( df -h | grep $TMP_FTP &>/dev/null ) 
    then
        find $TMP_FTP -maxdeth 1 -type f -mtime +$N -exec rm '{}' \; \
            && echo -e "delete old backups on $TMP_FTP ok; `date +%T`\n" >> $LOG\
            || echo -e "delete old backups on $TMP_FTP alarm; `date +%T`\n" >> $LOG
    else
        echo -e "ALARM! $TMP_FTP not mount" >> $LOG
    fi
}
MAIN_FUNCTION () {
    DUMP_FILE
    DUMP_MYSQL
    DELETE_OLD_LOCAL
    DELETE_OLD_REMOTE
    umount $TMP_FTP
}
CHECK_FREE_SPACE () {
    PART="home backup"
    MIN_SIZE='30'
    for P in $PART; do
        FREE_SPACE=`df -h | grep "$P" | awk '{print$4}' | sed 's/G//'`
        if [ "$FREE_SPACE" -lt "$MIN_SIZE" ]
        then
            echo -e "no free space in $P" >> $LOG
        else
            >/dev/null
        fi
    done
    if ( grep 'no free space' $LOG)
    then
        umount $TMP_FTP; exit 0
    else
        MAIN_FUNCTION
    fi
}
MOUNT_FTP
CHECK_FREE_SPACE
echo -e "end backups `date +%T`\n============================" >> $LOG
