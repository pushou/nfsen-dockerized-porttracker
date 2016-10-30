#!/bin/sh

# fancy pants colored bash outputs
RESTORE=$(echo -en '\033[0m')
RED=$(echo -en '\033[00;31m')
GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
BLUE=$(echo -en '\033[00;34m')
LRED=$(echo -en '\033[01;31m')
LGREEN=$(echo -en '\033[01;32m')
LYELLOW=$(echo -en '\033[01;33m')
LBLUE=$(echo -en '\033[01;34m')

# symlink nf commands to $PATH
ln -s /data/nfsen/bin/nfsen /usr/local/bin/nfsen
ln -s /data/nfsen/bin/nfsend /usr/local/bin/nfsend
ln -s /data/flow-generator /usr/local/bin/flow-generator

# TODO add to supervisord
if [ -f /data/nfsen/bin/nfsen ]; then
    echo "Starting nfsen and apache.."
    /data/nfsen/bin/nfsen start
    sleep 3
else
    echo "nsfen binary not found in /data/nfsen/bin/"
fi


echo -e "${LYELLOW} *Note*:${RESTORE} Above errors ${LYELLOW}ERR Channel info file missing${RESTORE} are expected until flow data creates the files."
echo "${GREEN}### Done! ${RESTORE} point your browser at http://<ip_address>>/nfsen/nfsen.php and change"
echo -e "${GREEN}### ${RESTORE} the profile to ${RED}zone1_profile${RESTORE} to view the example predefined filters"
echo -e "${GREEN}### ${RESTORE} Run 'nfsen status' to view daemon status and details and 'netstat -lntu' to view listening ports."
echo -e "${BLUE}### ${RESTORE} If you want to generate some test flows, I wrote a quick flow generator app that is in the /data/ directory"
echo -e "${BLUE}### ${RESTORE} ${RED}flow-generator  -t 127.0.0.1 -p 9995${RESTORE}"
echo -e "If you let it run for around 15-20 minutes or so and you should see flows being generated in the web ui"
echo -e ''
echo -e "${BLUE}### ${RESTORE} 'You can also put any other collector target address you want to test against. The generated protocols match the nfsen sample filter above"
