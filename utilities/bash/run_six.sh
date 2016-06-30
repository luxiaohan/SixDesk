#!/bin/bash

function how_to_use() {
    cat <<EOF

   `basename $0` [action] [option]
   to manage the submission of sixtrack jobs

   actions (mandatory, one of the following):
   -p      prepare simulation files 
           NB: this includes also preliminary SixTrakc jobs for computing
               chromas and beta functions
   -s      actually submit
   -c      check that all the input files have been created
           NB: this is done by default after preparation or before submission,
               but this action can be triggered on its own

   By default, all actions are performed no matter if jobs are 
      partially prepared/run.

   options (optional)
   -S      selected points of scan only
           in case of preparation of files, regenerate all directories
              with an incomplete set of input files;
           in case of submission, submit all directories without a fort.10.gz
           NB: this option is NOT active in case of -c only!

EOF
}

function preliminaryChecks(){
    lerr=-1
    # - check run requests
    let tmpTot=$da+$short+$long
    if [ $tmpTot -gt 1 ] ; then
	sixdeskmess="Please select only one among short/long/da run"
	sixdeskmess
	lerr=1
    fi

    # - check definition of amplitude range
    if [ $short -eq 1 ] ; then
	Ampl="${ns1s}_${ns2s}"
    elif [ $long -eq 1 ] ;then
	Ampl="${ns1l}_${ns2l}"
    elif [ $da -eq 1 ] ;then
	Ampl="0$dimda"
    fi
    if [ -z "$Ampl" ] ;then
	sixdeskmess="Ampl not defined. Please check ns1s/ns2s or ns1l/ns2l or dimda..."
	sixdeskmess
	lerr=2
    fi
 
    # - check paths
    if [ ! -d ${sixtrack_input} ] ; then
	sixdeskmesslevel=1
	sixdeskmess="The directory ${sixtrack_input} does not exist!!!"
	sixdeskmess
	lerr=1
    fi
    ${SCRIPTDIR}/bash/mad6t.sh -c $newLHCDesName
    if [ $? -ne 0 ] ; then
	sixdeskmesslevel=1
	sixdeskmess="sixtrack_input appears incomplete!!!"
	sixdeskmess
	lerr=2
    fi

    # raise and error message
    if [ $lerr -gt -1 ] ; then
	sixdeskexit $lerr
    fi
}

function preProcessFort3(){
    local __POST=POST
    local __DIFF=DIFF

    # --------------------------------------------------------------------------
    # build fort.3 for momentum scan
    # - first part
    sed -e 's/%turnss/'1'/g' \
	-e 's/%nss/'1'/g' \
	-e 's/%ax0s/'0.'/g' \
	-e 's/%ax1s/'0.'/g' \
	-e 's/%imc/'31'/g' \
	-e 's/%iclo6/'0'/g' \
	-e 's/%writebins/'1'/g' \
	-e 's/%ratios/'0.'/g' \
	-e 's/%dp1/'$dpmax'/g' \
	-e 's/%dp2/'$dpmax'/g' \
	-e 's/%e0/'$e0'/g' \
	-e 's/%ition/'0'/g' \
	-e 's/%idfor/'$idfor'/g' \
	-e 's/%ibtype/'$ibtype'/g' \
	-e 's/%bunch_charge/'$bunch_charge'/g' \
	-e 's?%Runnam?%Runnam '"$sixdeskTitle"'?g' \
        $sixdeskjobs_logs/fort.3.mother1 > $sixdeskjobs_logs/fort0.3.mask
    # - multipole blocks
    cat $sixdeskjobs_logs/fort.3.mad >> $sixdeskjobs_logs/fort0.3.mask 
    # - second  part
    if [ $reson -eq 1 ] ; then
	local __Qx=`awk '{print $1}' resonance`
	local __Qy=`awk '{print $2}' resonance`
	local __Ax=`awk '{print $3}' resonance`
	local __Ay=`awk '{print $4}' resonance`
	local __N1=`awk '{print $5}' resonance`
	local __N2=`awk '{print $6}' resonance`
	sed -e 's/%SUB/''/g' \
	    -e 's/%Qx/'$__Qx'/g' \
	    -e 's/%Qy/'$__Qy'/g' \
	    -e 's/%Ax/'$__Ax'/g' \
	    -e 's/%Ay/'$__Ay'/g' \
	    -e 's/%chromx/'$chromx'/g' \
	    -e 's/%chromy/'$chromy'/g' \
	    -e 's/%N1/'$__N1'/g' \
	    -e 's/%N2/'$__N2'/g' -i $sixdeskjobs_logs/fort.3.mother2
    else
	sed -i -e 's/%SUB/\//g' $sixdeskjobs_logs/fort.3.mother2
    fi  
    local __ndafi="$__imc"
    sed -e 's?%CHRO?'$CHROVAL'?g' \
	-e 's?%TUNE?'$TUNEVAL'?g' \
	-e 's/%POST/'$__POST'/g' \
	-e 's/%POS1/''/g' \
	-e 's/%ndafi/'$__ndafi'/g' \
	-e 's/%chromx/'$chromx'/g' \
	-e 's/%chromy/'$chromy'/g' \
	-e 's/%DIFF/\/'$__DIFF'/g' \
	-e 's/%DIF1/\//g' $sixdeskjobs_logs/fort.3.mother2 >> $sixdeskjobs_logs/fort0.3.mask 
    sixdeskmess="Maximum relative energy deviation for momentum scan $dpmax"
    sixdeskmess

    # --------------------------------------------------------------------------
    # build fort.3 for detuning run
    # - first part
    if [ $dimen -eq 6 ] ; then
	local __imc=1
	local __iclo6=2
	local __ition=1
	local __dp1=$dpini
	local __dp2=$dpini
    else
	local __imc=1
	local __iclo6=0
	local __ition=0
	local __dp1=.000
	local __dp2=.000
    fi
    sed -e 's/%imc/'$__imc'/g' \
	-e 's/%iclo6/'$__iclo6'/g' \
	-e 's/%dp1/'$__dp1'/g' \
	-e 's/%dp2/'$__dp2'/g' \
	-e 's/%e0/'$e0'/g' \
	-e 's/%ition/'$__ition'/g' \
	-e 's/%idfor/'$__idfor'/g' \
	-e 's/%ibtype/'$ibtype'/g' \
	-e 's/%bunch_charge/'$bunch_charge'/g' \
	-e 's?%Runnam?%Runnam '"$sixdeskTitle"'?g' \
        $sixdeskjobs_logs/fort.3.mother1 > $sixdeskjobs_logs/forts.3.mask
    # - multipole blocks
    cat $sixdeskjobs_logs/fort.3.mad >> $sixdeskjobs_logs/forts.3.mask 
    # - second  part
    sed -e 's?%CHRO?'$CHROVAL'?g' \
	-e 's?%TUNE?'$TUNEVAL'?g' \
	-e 's/%POST/'$__POST'/g' \
	-e 's/%POS1/''/g' \
	-e 's/%ndafi/%nss/g' \
	-e 's/%chromx/'$chromx'/g' \
	-e 's/%chromy/'$chromy'/g' \
	-e 's/%DIFF/\/'$__DIFF'/g' \
	-e 's/%DIF1/\//g' $sixdeskjobs_logs/fort.3.mother2 >> $sixdeskjobs_logs/forts.3.mask 
    
    # --------------------------------------------------------------------------
    # build fort.3 for long term run
    # - first part
    local __imc=1
    if [ $dimen -eq 6 ] ; then
	local __iclo6=2
	local __ition=1
	local __dp1=$dpini
	local __dp2=$dpini
    else
	local __iclo6=0
	local __ition=0
	local __dp1=.0
	local __dp2=.0
    fi
    sed -e 's/%turnss/%turnsl/g' \
	-e 's/%nss/'$sixdeskpairs'/g' \
	-e 's/%imc/'$__imc'/g' \
	-e 's/%iclo6/'$__iclo6'/g' \
	-e 's/%ax0s/%ax0l/g' \
	-e 's/%ax1s/%ax1l/g' \
	-e 's/%writebins/%writebinl/g' \
	-e 's/%ratios/%ratiol/g' \
	-e 's/%dp1/'$__dp1'/g' \
	-e 's/%dp2/'$__dp2'/g' \
	-e 's/%e0/'$e0'/g' \
	-e 's/%ition/'$__ition'/g' \
	-e 's/%idfor/'$idfor'/g' \
	-e 's/%ibtype/'$ibtype'/g' \
	-e 's/%bunch_charge/'$bunch_charge'/g' \
	-e 's?%Runnam?%Runnam '"$sixdeskTitle"'?g' \
        $sixdeskjobs_logs/fort.3.mother1 > $sixdeskjobs_logs/fortl.3.mask
    # - multipole blocks
    cat $sixdeskjobs_logs/fort.3.mad >> $sixdeskjobs_logs/fortl.3.mask 
    # - second  part
    sed -e 's?%CHRO?'$CHROVAL'?g' \
	-e 's?%TUNE?'$TUNEVAL'?g' \
	-e 's/%POST/'$__POST'/g' \
	-e 's/%POS1/''/g' \
	-e 's/%ndafi/'$sixdeskpairs'/g' \
	-e 's/%chromx/'$chromx'/g' \
	-e 's/%chromy/'$chromy'/g' \
	-e 's/%DIFF/\/'$__DIFF'/g' \
	-e 's/%DIF1/\//g' $sixdeskjobs_logs/fort.3.mother2 >> $sixdeskjobs_logs/fortl.3.mask 
    sixdeskmess="Initial relative energy deviation $dpini"
    sixdeskmess

    # --------------------------------------------------------------------------
    # build fort.3 for DA run
    # - first part
    if [ $dimda -eq 6 ] ; then
	local __iclo6=2
	local __ition=1
	local __nsix=0
    else
	local __iclo6=0
	local __ition=0
	local __nsix=0
    fi
    sed -e 's/%turnss/'1'/g' \
	-e 's/%nss/'1'/g' \
	-e 's/%ax0s/'0.'/g' \
	-e 's/%ax1s/'0.'/g' \
	-e 's/%imc/'1'/g' \
	-e 's/%iclo6/'$__iclo6'/g' \
	-e 's/%writebins/'0'/g' \
	-e 's/%ratios/'0.'/g' \
	-e 's/%dp1/'.000'/g' \
	-e 's/%dp2/'.000'/g' \
	-e 's/%e0/'$e0'/g' \
	-e 's/%ition/'$__ition'/g' \
	-e 's/%idfor/'$idfor'/g' \
	-e 's/%ibtype/'$ibtype'/g' \
	-e 's/%bunch_charge/'$bunch_charge'/g' \
	-e 's?%Runnam?%Runnam '"$sixdeskTitle"'?g' \
        $sixdeskjobs_logs/fort.3.mother1 > $sixdeskjobs_logs/fortda.3.mask
    # - multipole blocks
    cat $sixdeskjobs_logs/fort.3.mad >> $sixdeskjobs_logs/fortda.3.mask 
    # - second  part
    sed -e 's?%CHRO?'$CHROVAL'?g' \
	-e 's?%TUNE?'$TUNEVAL'?g' \
	-e 's/%POST/\/'$__POST'/g' \
	-e 's/%POS1/\//g' \
	-e 's/%DIFF/'$__DIFF'/g' \
	-e 's/%chromx/'$chromx'/g' \
	-e 's/%chromy/'$chromy'/g' \
	-e 's/%nsix/'$__nsix'/g' \
	-e 's/%DIF1//g' $sixdeskjobs_logs/fort.3.mother2 >> $sixdeskjobs_logs/fortda.3.mask 
}

function preProcessShort(){
    if [ $sussix -eq 1 ] ; then
	local __IANA=1
	local __LR=1
	local __MR=0
	local __KR=0
	local __dimline=1
	sed -e 's/%nss/'$nss'/g' \
            -e 's/%IANA/'$__IANA'/g' \
            -e 's/%turnss/'$turnss'/g' \
            -e 's/%dimsus/'$dimsus'/g' \
            -e 's/%LR/'$__LR'/g' \
            -e 's/%MR/'$__MR'/g' \
            -e 's/%KR/'$__KR'/g' \
            -e 's/%dimline/'$__dimline'/g' ${SCRIPTDIR}/templates/sussix/sussix.inp > \
            $sixdeskjobs_logs/sussix.tmp.1
	local __IANA=0
	local __LR=0
	local __MR=1
	local __dimline=2
	sed -e 's/%nss/'$nss'/g' \
            -e 's/%IANA/'$__IANA'/g' \
            -e 's/%turnss/'$turnss'/g' \
            -e 's/%dimsus/'$dimsus'/g' \
            -e 's/%LR/'$__LR'/g' \
            -e 's/%MR/'$__MR'/g' \
            -e 's/%KR/'$__KR'/g' \
            -e 's/%dimline/'$__dimline'/g' ${SCRIPTDIR}/templates/sussix/sussix.inp > \
            $sixdeskjobs_logs/sussix.tmp.2
	local __MR=0
	local __KR=1
	local __dimline=3
	sed -e 's/%nss/'$nss'/g' \
            -e 's/%IANA/'$__IANA'/g' \
            -e 's/%turnss/'$turnss'/g' \
            -e 's/%dimsus/'$dimsus'/g' \
            -e 's/%LR/'$__LR'/g' \
            -e 's/%MR/'$__MR'/g' \
            -e 's/%KR/'$__KR'/g' \
            -e 's/%dimline/'$__dimline'/g' ${SCRIPTDIR}/templates/sussix/sussix.inp > \
            $sixdeskjobs_logs/sussix.tmp.3
	sed -e 's/%suss//g' \
	    ${SCRIPTDIR}/templates/lsf/${lsfjobtype}.job > $sixdeskjobs_logs/${lsfjobtype}.job
    else
	sed -e 's/%suss/'#'/g' \
            ${SCRIPTDIR}/templates/lsf/${lsfjobtype}.job > $sixdeskjobs_logs/${lsfjobtype}.job
	chmod 755 $sixdeskjobs_logs/${lsfjobtype}.job
    fi
    sed -i -e 's?SIXTRACKEXE?'$SIXTRACKEXE'?g' \
           -e 's?SIXDESKHOME?'$sixdeskhome'?g' $sixdeskjobs_logs/${lsfjobtype}.job
    chmod 755 $sixdeskjobs_logs/${lsfjobtype}.job
    sed -e 's/%suss/'#'/g' \
        -e 's?SIXTRACKEXE?'$SIXTRACKEXE'?g' \
	-e 's?SIXDESKHOME?'$sixdeskhome'?g' \
        ${SCRIPTDIR}/templates/lsf/${lsfjobtype}.job > $sixdeskjobs_logs/${lsfjobtype}0.job
    chmod 755 $sixdeskjobs_logs/${lsfjobtype}0.job
}

function preProcessDA(){
    if [ $dimda -eq 6 ] ; then
	cp $sixdeskhome/inc/dalie6.data $sixdeskjobs_logs/dalie.data
	sed -e 's/%NO/'$NO1'/g' \
	    -e 's/%NV/'$NV'/g' $sixdeskhome/inc/dalie6.mask > $sixdeskjobs_logs/dalie.input
	cp $sixdeskhome/bin/dalie6 $sixdeskjobs_logs/dalie
    else
	sed -e 's/%NO/'$NO'/g' $sixdeskhome/inc/dalie4.data.mask > $sixdeskjobs_logs/dalie.data
	sed -e 's/%NO/'$NO1'/g' \
	    -e 's/%NV/'$NV'/g' $sixdeskhome/inc/dalie4.mask > $sixdeskjobs_logs/dalie.input
	cp $sixdeskhome/bin/dalie4 $sixdeskjobs_logs/dalie
    fi
    cp $sixdeskhome/inc/reson.data $sixdeskjobs_logs
    cp $sixdeskhome/bin/readda $sixdeskjobs_logs
}

function inspectPrerequisites(){
    local __path=$1
    local __test=$2
    shift 2
    local __files=$@
    for tmpFile in ${__files} ; do
	test $__test ${__path}/${tmpFile}
	tmpStat=$?
	if [ $tmpStat -ne 0 ] ; then
	    sixdeskmess="${__path}/${tmpFile} not there!"
	    sixdeskmess
	fi
	let lerr+=$tmpStat
    done
}

function submitChromaJobs(){

    local __destination=$1
    
    # --------------------------------------------------------------------------
    # generate appropriate fort.3 files as: fort.3.tx + fort.3.mad + fort.3.m2
    # - fort.3.t1 (from .mother1)
    sed -e 's/%turnss/'1'/g' \
        -e 's/%nss/'1'/g' \
        -e 's/%ax0s/'.1'/g' \
        -e 's/%ax1s/'.1'/g' \
        -e 's/%imc/'1'/g' \
        -e 's/%iclo6/'2'/g' \
        -e 's/%writebins/'1'/g' \
        -e 's/%ratios/'1'/g' \
        -e 's/%dp1/'.000'/g' \
        -e 's/%dp2/'.000'/g' \
        -e 's/%e0/'$e0'/g' \
        -e 's/%Runnam/First Turn/g' \
        -e 's/%idfor/0/g' \
        -e 's/%ibtype/0/g' \
        -e 's/%bunch_charge/'$bunch_charge'/g' \
        -e 's/%ition/'0'/g' ${sixtrack_input}/fort.3.mother1 > fort.3.t1
    # - fort.3.t2 (from .mother1)
    sed -e 's/%turnss/'1'/g' \
        -e 's/%nss/'1'/g' \
        -e 's/%ax0s/'.1'/g' \
        -e 's/%ax1s/'.1'/g' \
        -e 's/%imc/'1'/g' \
        -e 's/%iclo6/'2'/g' \
        -e 's/%writebins/'1'/g' \
        -e 's/%ratios/'1'/g' \
        -e 's/%dp1/'$chrom_eps'/g' \
        -e 's/%dp2/'$chrom_eps'/g' \
        -e 's/%e0/'$e0'/g' \
        -e 's/%Runnam/First Turn/g' \
        -e 's/%idfor/0/g' \
        -e 's/%ibtype/0/g' \
        -e 's/%bunch_charge/'$bunch_charge'/g' \
        -e 's/%ition/'0'/g' ${sixtrack_input}/fort.3.mother1 > fort.3.t2
    # - fort.3.m2 (from .mother2)
    local __CHROVAL='/'
    sed -e 's?%CHRO?'$__CHROVAL'?g' \
        -e 's?%TUNE?'$TUNEVAL'?g' \
        -e 's/%POST/'POST'/g' \
        -e 's/%POS1/''/g' \
        -e 's/%ndafi/'1'/g' \
        -e 's/%tunex/'$tunexx'/g' \
        -e 's/%tuney/'$tuneyy'/g' \
        -e 's/%chromx/'$chromx'/g' \
        -e 's/%chromy/'$chromy'/g' \
        -e 's/%inttunex/'$inttunexx'/g' \
        -e 's/%inttuney/'$inttuneyy'/g' \
        -e 's/%DIFF/\/DIFF/g' \
        -e 's/%DIF1/\//g' $sixdeskjobs_logs/fort.3.mother2 > fort.3.m2

    # --------------------------------------------------------------------------
    # prepare the other input files
    gunzip -c ${sixtrack_input}/fort.16_$iMad.gz > fort.16
    gunzip -c ${sixtrack_input}/fort.2_$iMad.gz > fort.2
    if [ -e ${sixtrack_input}/fort.8_$iMad.gz ] ; then
        gunzip -c ${sixtrack_input}/fort.8_$iMad.gz > fort.8
    else
        touch fort.8
    fi
    
    # --------------------------------------------------------------------------
    # actually run
    
    # - first job
    sixdeskmess="Running the first one turn job for chromaticity"
    sixdeskmess
    cat fort.3.t1 fort.3.mad fort.3.m2 > fort.3
    rm -f fort.10
    $SIXTRACKEXE > first_oneturn
    if test $? -ne 0 -o ! -s fort.10 ; then
        sixdeskmess="The first turn Sixtrack for chromaticity FAILED!!!"
        sixdeskmess
        sixdeskmess="Look in $sixdeskjobs_logs to see SixTrack input and output."
        sixdeskmess
        sixdeskmess="Check the file first_oneturn which contains the SixTrack fort.6 output."
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 77
    fi
    mv fort.10 fort.10_first_oneturn

    # - second job
    sixdeskmess="Running the second one turn job for chromaticity"
    sixdeskmess
    cat fort.3.t2 fort.3.mad fort.3.m2 > fort.3
    rm -f fort.10
    $SIXTRACKEXE > second_oneturn
    if test $? -ne 0 -o ! -s fort.10 ; then
        sixdeskmess="The second turn Sixtrack for chromaticity FAILED!!!"
        sixdeskmess
        sixdeskmess="Look in $sixdeskjobs_logs to see SixTrack input and output."
        sixdeskmess
        sixdeskmess="Check the file second_oneturn which contains the SixTrack fort.6 output."
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 78
    fi
    mv fort.10 fort.10_second_oneturn

    # --------------------------------------------------------------------------
    # a bit of arithmetic
    echo "$chrom_eps" > $__destination/sixdesktunes
    gawk 'FNR==1{print $3, $4}' < fort.10_first_oneturn >> $__destination/sixdesktunes
    gawk 'FNR==1{print $3, $4}' < fort.10_second_oneturn >> $__destination/sixdesktunes
    mychrom=`gawk 'FNR==1{E=$1}FNR==2{A=$1;B=$2}FNR==3{C=$1;D=$2}END{print (C-A)/E,(D-B)/E}' < $__destination/sixdesktunes`
    echo "$mychrom" > $__destination/mychrom          
    sixdeskmess="Chromaticity computed as $mychrom"
    sixdeskmess
    
}

function submitBetaJob(){
    
    local __destination=$1
    
    # --------------------------------------------------------------------------
    # generate appropriate fort.3 files as: fort.3.m1 + fort.3.mad + fort.3.m2
    sed -e 's/%turnss/'1'/g' \
        -e 's/%nss/'1'/g' \
        -e 's/%ax0s/'.1'/g' \
        -e 's/%ax1s/'.1'/g' \
        -e 's/%imc/'1'/g' \
        -e 's/%iclo6/'2'/g' \
        -e 's/%writebins/'1'/g' \
        -e 's/%ratios/'1'/g' \
        -e 's/%dp1/'.000'/g' \
        -e 's/%dp2/'.000'/g' \
        -e 's/%e0/'$e0'/g' \
        -e 's/%Runnam/One Turn/g' \
        -e 's/%idfor/0/g' \
        -e 's/%ibtype/0/g' \
        -e 's/%bunch_charge/'$bunch_charge'/g' \
        -e 's/%ition/'1'/g' ${sixtrack_input}/fort.3.mother1 > fort.3.m1
    sed -e 's?%CHRO?'$CHROVAL'?g' \
        -e 's?%TUNE?'$TUNEVAL'?g' \
        -e 's/%POST/'POST'/g' \
        -e 's/%POS1/''/g' \
        -e 's/%ndafi/'1'/g' \
        -e 's/%tunex/'$tunexx'/g' \
        -e 's/%tuney/'$tuneyy'/g' \
        -e 's/%chromx/'$chromx'/g' \
        -e 's/%chromy/'$chromy'/g' \
        -e 's/%inttunex/'$inttunexx'/g' \
        -e 's/%inttuney/'$inttuneyy'/g' \
        -e 's/%DIFF/\/DIFF/g' \
        -e 's/%DIF1/\//g' $sixdeskjobs_logs/fort.3.mother2 > fort.3.m2
    cat fort.3.m1 fort.3.mad fort.3.m2 > fort.3
    
    # --------------------------------------------------------------------------
    # prepare the other input files
    gunzip -c ${sixtrack_input}/fort.16_$iMad.gz > fort.16
    gunzip -c ${sixtrack_input}/fort.2_$iMad.gz > fort.2
    if [ -e ${sixtrack_input}/fort.8_$iMad.gz ] ; then
        gunzip -c ${sixtrack_input}/fort.8_$iMad.gz > fort.8
    else
        touch fort.8
    fi

    # --------------------------------------------------------------------------
    # actually run
    rm -f fort.10
    $SIXTRACKEXE > lin
    if test $? -ne 0 -o ! -s fort.10 ; then
        sixdeskmess="The one turn Sixtrack for betavalues FAILED!!!"
        sixdeskmess
        sixdeskmess="Look in $sixdeskjobs_logs to see SixTrack input and output."
        sixdeskmess
        sixdeskmess="Check the file lin which contains the SixTrack fort.6 output."
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 99
    fi
    mv lin lin_old
    cp fort.10 fort.10_old

    # --------------------------------------------------------------------------
    # regenerate betavalues file
    echo `gawk 'FNR==1{print $5, $48, $6, $49, $3, $4, $50, $51, $53, $54, $55, $56, $57, $58}' fort.10` > $__destination/betavalues
    # but if chrom=0 we need to update chromx, chromy
    if [ $chrom -eq 0 ] ; then
        beta_x=`gawk '{print $1}' $__destination/betavalues`
        beta_x2=`gawk '{print $2}' $__destination/betavalues`
        beta_y=`gawk '{print $3}' $__destination/betavalues`
        beta_y2=`gawk '{print $4}' $__destination/betavalues`
        mychromx=`gawk '{print $1}' $__destination/mychrom`
        mychromy=`gawk '{print $2}' $__destination/mychrom`
        htune=`gawk '{print $5}' $__destination/betavalues`
        vtune=`gawk '{print $6}' $__destination/betavalues`
        closed_orbit=`awk '{print ($9,$10,$11,$12,$13,$14)}' $__destination/betavalues`
        echo "$beta_x $beta_x2 $beta_y $beta_y2 $htune $vtune $mychromx $mychromy $closed_orbit" > $__destination/betavalues
    fi
    
}

function parseBetaValues(){

    local __betaWhere=$1

    # check that the betavalues file contains all the necessary values
    nBetas=`cat $__betaWhere/betavalues | wc -w`
    if [ $nBetas -ne 14 ] ; then
        sixdeskmess="betavalues has $nBetas words!!! Should be 14!"
        sixdeskmess
        rm -f $__betaWhere/betavalues
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 98
    fi

    # check that the beta values are not NULL and notify user
    beta_x=`gawk '{print $1}' $__betaWhere/betavalues`
    beta_x2=`gawk '{print $2}' $__betaWhere/betavalues`
    beta_y=`gawk '{print $3}' $__betaWhere/betavalues`
    beta_y2=`gawk '{print $4}' $__betaWhere/betavalues`
    if test "$beta_x" = "" -o "$beta_y" = "" -o "$beta_x2" = "" -o "beta_y2" = "" ; then
        # clean up for a retry by removing old betavalues
	# anyway, this run was not ok...
        rm -f $__betaWhere/betavalues
        sixdeskmess="One or more betavalues are NULL !!!"
        sixdeskmess
        sixdeskmess="Look in $sixdeskjobs_logs to see SixTrack input and output."
        sixdeskmess
        sixdeskmess="Check the file lin_old which contains the SixTrack fort.6 output."
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 98
    fi
    sixdeskmess=" Finally all betavalues:"
    sixdeskmess
    sixdeskmess="beta_x[2] $beta_x $beta_x2 - beta_y[2] $beta_y $beta_y2"
    sixdeskmess

    # notify user other variables
    fhtune=`gawk '{print $5}' $__betaWhere/betavalues`
    fvtune=`gawk '{print $6}' $__betaWhere/betavalues`
    fchromx=`gawk '{print $7}' $__betaWhere/betavalues`
    fchromy=`gawk '{print $8}' $__betaWhere/betavalues`
    fclosed_orbit=`gawk '{print $9" "$10" "$11" "$12" "$13" "$14}' $__betaWhere/betavalues`
    sixdeskmess="Chromaticity: $fchromx $fchromy"
    sixdeskmess
    sixdeskmess="Tunes: $fhtune $fvtune"
    sixdeskmess
    sixdeskmess="Closed orbit: $fclosed_orbit"
    sixdeskmess

}

function submitCreateRundir(){
    local __RunDirFullPath=$1
    if [ -d $__RunDirFullPath ] ; then
	if [ -s $__RunDirFullPath/fort.10.gz ] ; then
	    # relink
	    rm -f $actualDirNameFullPath
	    ln -fs $__RunDirFullPath $actualDirNameFullPath
	    sixdeskmesslevel=1
	    sixdeskmess="$__RunDirFullPath relinked as $actualDirNameFullPath"
	    sixdeskmess
	else
	    rm -rf $__RunDirFullPath
	    sixdeskmesslevel=1
	    sixdeskmess="old $__RunDirFullPath removed - contained no or zerolength fort.10"
	    sixdeskmess
	fi
    fi
    if [ ! -d $__RunDirFullPath ] ; then
        mkdir -p $__RunDirFullPath
    fi
}

function submitCreateLinks(){
    local __RunDirFullPath=$1
    local __6TinputFullPath=$2
    local __workingDirFullPath=$3
    if [ -e $__6TinputFullPath/fort.2_$iMad.gz ] ; then
        ln -s $__6TinputFullPath/fort.2_$iMad.gz  $__RunDirFullPath/fort.2.gz
    else
        sixdeskmesslevel=0
        sixdeskmess="No SIXTRACK geometry file (fort.2): Run stopped"
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 4
    fi
    if [ -e $__workingDirFullPath/fort.3 ] ; then
        gzip -c $__workingDirFullPath/fort.3 > $__RunDirFullPath/fort.3.gz
    else
        sixdeskmesslevel=0
        sixdeskmess="No SIXTRACK control file (fort.3): Run stopped"
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 5
    fi
    if [ -e $__6TinputFullPath/fort.8_$iMad.gz ] ; then
        ln -s $__6TinputFullPath/fort.8_$iMad.gz  $__RunDirFullPath/fort.8.gz
    else
        sixdeskmesslevel=0
        sixdeskmess="No SIXTRACK misalignment file (fort.8): dummy file created"
        sixdeskmess
        touch $__RunDirFullPath/fort.8
        gzip $__RunDirFullPath/fort.8
    fi
    if [ -e $__6TinputFullPath/fort.16_$iMad.gz ] ; then
        ln -s $__6TinputFullPath/fort.16_$iMad.gz  $__RunDirFullPath/fort.16.gz
    else
        sixdeskmesslevel=0
        sixdeskmess="No SIXTRACK error file (fort.16): dummy file created"
        sixdeskmess
        touch $__RunDirFullPath/fort.16
        gzip $__RunDirFullPath/fort.16
    fi
}

function dot_bsub(){
    
    # clean, in case
    if [ -s $RundirFullPath/fort.10.gz ] ; then
	rm -f $RundirFullPath/fort.10.gz
	sed -i -e'/^'$Runnam'$/d' $sixdeskwork/completed_cases
	sed -i -e'/^'$Runnam'$/d' $sixdeskwork/mycompleted_cases
    fi
    
    # actually submit
    bsub -q $lsfq $sixdeskM -o $RundirFullPath/$Runnam.log < $RundirFullPath/$Runnam.job > tmp 2>&1

    # verify that submission was successfull
    if  [ $? -eq 0 ] ; then
	local __taskno=`tail -1 tmp | sed -e's/Job <\([0-9]*\)> is submitted to queue.*/\1/'`
	if [ "$__taskno" == "" ] ; then
	    sixdeskmess="bsub did NOT return a taskno !!!"
	    sixdeskmess
	    sixdeskexit 21
	fi
	local __taskid=lsf$__taskno
	touch $RundirFullPath/JOB_NOT_YET_STARTED
    else
	rm -f $RundirFullPath/JOB_NOT_YET_STARTED 
	sixdeskmess="bsub of $RundirFullPath/$Runnam.job to Queue ${lsfq} failed !!!"
	sixdeskmess
	sixdeskexit 10
    fi

    # keep track of the $Runnam-taskid couple
    local __oldtaskid=`grep "$Runnam " $sixdeskwork/taskids`
    if [ -n "$__oldtaskid" ] ; then
	__oldtaskid=`echo $__oldtaskid | cut -f2`
	sed -i -e'/'$Runnam' /d' $sixdeskwork/taskids
	__taskids=$__oldtaskid" "$__taskid" "
	sixdeskmesslevel=1
	sixdeskmess="Job $Runnam re-submitted with JobId/taskid $__taskid; old JobId/taskid $__oldtaskid"
	sixdeskmess
    else
	__taskids=$__taskid
	echo $Runnam >> $sixdeskwork/incomplete_cases
	echo $Runnam >> $sixdeskwork/myincomplete_cases
	sixdeskmesslevel=1
	sixdeskmess="Job $Runnam submitted with LSF JobId/taskid $__taskid"
	sixdeskmess
    fi
    echo "$Runnam" "$__taskids" >> $sixdeskwork/taskids
    echo "$sixdeskRunnam" "$__taskid" >> $sixdeskjobs/jobs
    echo "$sixdeskRunnam" "$__taskid" >> $sixdeskjobs/incomplete_jobs
    rm -f tmp
    
}

function treatShort(){

    local __lReady=false
    local __lGenerate=false

    if ${lprepare} ; then
	if [ $sussix -eq 1 ] ; then
	    # and now we get fractional tunes to plug in qx/qy
            qx=`gawk 'END{qx='$fhtune'-int('$fhtune');print qx}' /dev/null`
            qy=`gawk 'END{qy='$fvtune'-int('$fvtune');print qy}' /dev/null`
            sixdeskmess="Sussix tunes set to $qx, $qy from $fhtune, $fvtune"
            sixdeskmess
            sed -e 's/%qx/'$qx'/g' \
		-e 's/%qy/'$qy'/g' $sixdeskjobs_logs/sussix.tmp.1 > $sixdeskjobs_logs/sussix.inp.1
            sed -e 's/%qx/'$qx'/g' \
		-e 's/%qy/'$qy'/g' $sixdeskjobs_logs/sussix.tmp.2 > $sixdeskjobs_logs/sussix.inp.2
            sed -e 's/%qx/'$qx'/g' \
		-e 's/%qy/'$qy'/g' $sixdeskjobs_logs/sussix.tmp.3 > $sixdeskjobs_logs/sussix.inp.3
	fi
    fi
    if ${lcheck} ; then
	if [ $sussix -eq 1 ] ; then
	    lerr=0
	    inspectPrerequisites $sixdeskjobs_logs -e sussix.tmp.1 sussix.tmp.2 sussix.tmp.3
	    if [ ${lerr} -gt 0 ] ; then
		sixdeskmess="Error while creating sussix input files"
		sixdeskmess
		sixdesklockdir=$sixdeskstudy
		sixdeskunlock
		sixdeskexit 47
	    fi
	fi
    fi

    # get AngleStep
    sixdeskAngleStep 90 $kmax
    # loop over angles
    for (( kk=$kini; kk<=$kend; kk+=$kstep )) ; do

	# get Angle and kang
	sixdeskAngle $AngleStep $kk
	sixdeskkang $kk $kmax

	# get dirs for this point in scan (returns Runnam, Rundir, actualDirName)
	# ...and notify user
        sixdeskmesslevel=1
        if [ $kk -eq 0 ] ; then
	    sixdeskDefinePointTree $LHCDesName $iMad "m" $sixdesktunes "__" "0" $Angle $kk $sixdesktrack
            sixdeskmess="Momen $Runnam $Rundir, k=$kk"
	else
	    sixdeskDefinePointTree $LHCDesName $iMad "t" $sixdesktunes $Ampl $turnsse $Angle $kk $sixdesktrack
            sixdeskmess="Trans $Runnam $Rundir, k=$kk"
        fi
        sixdeskmess

	if ${lprepare} ; then
	    if ${lselected} ; then
		lerr=0
		inspectPrerequisites $RundirFullPath -d ""
		inspectPrerequisites $RundirFullPath -s $Runnam.job
		inspectPrerequisites $RundirFullPath -s fort.2.gz fort.3.gz fort.8.gz fort.16.gz
		if [ $sussix -eq 1 ] ; then
		    inspectPrerequisites $RundirFullPath -s sussix.inp.1 sussix.inp.2 sussix.inp.3
		fi
		if [ ${lerr} -gt 0 ] ; then
		    sixdeskmess="$RundirFullPath NOT ready for submission - regenerating ALL input files!"
		    sixdeskmess
		    __lGenerate=true
		fi
	    else
		__lGenerate=true
	    fi

	    if ${__lGenerate} ; then
	    
		# does rundir exist?
		submitCreateRundir $RundirFullPath
	
		# finalise generation of fort.3
		if [ $kk -eq 0 ] ; then
		    sed -e 's/%Runnam/'$Runnam'/g' \
			-e 's/%tunex/'$tunexx'/g' \
			-e 's/%tuney/'$tuneyy'/g' \
			-e 's/%inttunex/'$inttunexx'/g' \
			-e 's/%inttuney/'$inttuneyy'/g' $sixdeskjobs_logs/fort0.3.mask > $sixdeskjobs_logs/fort.3
		else
		    # returns ratio
		    sixdeskRatio $kk
		    # returns ax0 and ax1
		    sixdeskax0 $factor $beta_x $beta_x2 $beta_y $beta_y2 $ratio $kk $square $ns1s $ns2s
		    sed -e 's/%nss/'$nss'/g' \
			-e 's/%turnss/'$turnss'/g' \
			-e 's/%ax0s/'$ax0'/g' \
			-e 's/%ax1s/'$ax1'/g' \
			-e 's/%ratios/'$ratio'/g' \
			-e 's/%tunex/'$tunexx'/g' \
			-e 's/%tuney/'$tuneyy'/g' \
			-e 's/%inttunex/'$inttunexx'/g' \
			-e 's/%inttuney/'$inttuneyy'/g' \
			-e 's/%Runnam/'$Runnam'/g' \
			-e 's/%writebins/'$writebins'/g' $sixdeskjobs_logs/forts.3.mask > $sixdeskjobs_logs/fort.3
		fi
		
		# final preparation of all SIXTRACK files
		submitCreateLinks $RundirFullPath $sixtrack_input $sixdeskjobs_logs
		
		# sussix input files
		if [ $sussix -eq 1 ] ; then
		    for tmpI in $(seq 1 3) ; do
			cp $sixdeskjobs_logs/sussix.inp.$tmpI $RundirFullPath
		    done
		fi
	    
		# submission file
		if [ $kk -eq 0 ] ; then
		    sed -e 's?SIXJOBNAME?'$Runnam'?g' \
			-e 's?SIXJOBDIR?'$Rundir'?g' \
			-e 's?SIXTRACKDIR?'$sixdesktrack'?g' \
			-e 's?SIXJUNKTMP?'$sixdeskjobs_logs'?g' $sixdeskjobs_logs/${lsfjobtype}0.job > $RundirFullPath/$Runnam.job
		else
		    sed -e 's?SIXJOBNAME?'$Runnam'?g' \
			-e 's?SIXJOBDIR?'$Rundir'?g' \
			-e 's?SIXTRACKDIR?'$sixdesktrack'?g' \
			-e 's?SIXJUNKTMP?'$sixdeskjobs_logs'?g' $sixdeskjobs_logs/${lsfjobtype}.job > $RundirFullPath/$Runnam.job
		fi
		chmod 755 $RundirFullPath/$Runnam.job
	    fi
	fi
	if ${lcheck} ; then
	    lerr=0
	    if [ "$sixdeskplatform" != "lsf" ] ; then
		sixdeskmess="Only LSF platform for short runs!"
		sixdeskmess
		let lerr+=$?
	    fi
	    inspectPrerequisites $RundirFullPath -d ""
	    inspectPrerequisites $RundirFullPath -s $Runnam.job
	    inspectPrerequisites $RundirFullPath -s fort.2.gz fort.3.gz fort.8.gz fort.16.gz
	    if [ $sussix -eq 1 ] ; then
		inspectPrerequisites $RundirFullPath -s sussix.inp.1 sussix.inp.2 sussix.inp.3
	    fi
	    if [ ${lerr} -gt 0 ] ; then
		sixdeskmess="$RundirFullPath NOT ready for submission!"
		sixdeskmess
	    elif ${lselected} && [ -s $RundirFullPath/fort.10.gz ] ; then
		# sensitive to jobs already run
		sixdeskmess="job in $RundirFullPath already run!"
		sixdeskmess
	    else
		__lReady=true
		sixdeskmess="$RundirFullPath ready to submit!"
		sixdeskmess
	    fi
	fi
	if ${lsubmit} ; then
	    if ${__lReady} ; then
		dot_bsub
	    else
		sixdeskmess="Missing input info - cannot submit!"
		sixdeskmess
	    fi
	fi
	
    done

}

function treatLong(){

    sixdeskamps

    # loop over amplitudes
    while test $ampstart -lt $ampfinish ; do
        fampstart=`gawk 'END{fnn='$ampstart'/1000.;printf ("%.3f\n",fnn)}' /dev/null`
        fampstart=`echo $fampstart | sed -e's/0*$//'`
        fampstart=`echo $fampstart | sed -e's/\.$//'`
        ampend=`expr "$ampstart" + "$ampincl"`
        fampend=`gawk 'END{fnn='$ampend'/1000.;printf ("%.3f\n",fnn)}' /dev/null`
        fampend=`echo $fampend | sed -e's/0*$//'`
        fampend=`echo $fampend | sed -e's/\.$//'`
        Ampl="${fampstart}_${fampend}"

        sixdeskmesslevel=0
        sixdeskmess="Loop over amplitudes: $Ampl $ns1l $ns2l $nsincl"
        sixdeskmess
        sixdeskmess="$ampstart $ampfinish $ampincl $fampstart $fampend"
        sixdeskmess

	# get AngleStep
	sixdeskAngleStep 90 $kmaxl
	# loop over angles
	for (( kk=$kinil; kk<=$kendl; kk+$kstep )) ; do

	    # get Angle and kang
	    sixdeskAngle $AngleStep $kk
	    sixdeskkang $kk $kmaxl

	    # get dirs for this point in scan (returns Runnam, Rundir, actualDirName)
	    sixdeskDefinePointTree $LHCDesName $iMad "s" $sixdesktunes $Ampl $turnsle $Angle $kk $sixdesktrack
	    
	    if ${lprepare} ; then
		# does rundir exist?
		submitCreateRundir $RundirFullPath

		# finalise generation of fort.3
		# returns ratio
		sixdeskRatio $kk
		# returns ax0 and ax1
		sixdeskax0 $factor $beta_x $beta_x2 $beta_y $beta_y2 $ratio $kk $square $fampstart $fampend
		#
		sed -e 's/%turnsl/'$turnsl'/g' \
                    -e 's/%ax0l/'$ax0'/g' \
                    -e 's/%ax1l/'$ax1'/g' \
                    -e 's/%ratiol/'$ratio'/g' \
                    -e 's/%tunex/'$tunexx'/g' \
                    -e 's/%tuney/'$tuneyy'/g' \
                    -e 's/%inttunex/'$inttunexx'/g' \
                    -e 's/%inttuney/'$inttuneyy'/g' \
                    -e 's/%Runnam/'$Runnam'/g' \
                    -e 's/%writebinl/'$writebinl'/g' $sixdeskjobs_logs/fortl.3.mask > $sixdeskjobs_logs/fort.3
	    
		# final preparation of all SIXTRACK files
		submitCreateLinks $RundirFullPath $sixtrack_input $sixdeskjobs_logs

		# submission file
		if [ "$sixdeskplatform" == "lsf" ] ; then
		    sed -e 's?SIXJOBNAME?'$Runnam'?g' \
			-e 's?SIXJOBDIR?'$Rundir'?g' \
			-e 's?SIXTRACKDIR?'$sixdesktrack'?g' \
			-e 's?SIXTRACKEXE?'$SIXTRACKEXE'?g' \
			-e 's?SIXCASTOR?'$sixdeskcastor'?g' \
			-e 's?SIXJUNKTMP?'$sixdeskjobs_logs'?g' $sixdeskhome/utilities/${lsfjobtype}.job > $RundirFullPath/$Runnam.job
		    chmod 755 $RundirFullPath/$Runnam.job
		elif [ "$sixdeskplatform" == "grid" ] ; then
		    # Create $Runnam.grid in $sixdeskwork/$Runnam
		    sixdeskmesslevel=0
		    sixdeskmess="Running on GRID not yet implemented!!!"
		    sixdeskmess
		    sixdesklockdir=$sixdeskjobs_logs
		    sixdeskunlock
		    sixdesklockdir=$sixdeskstudy
		    sixdeskunlock
		    sixdeskexit 9
		elif [ "$sixdeskplatform" != "cpss" ] && [ "$sixdeskplatform" == "boinc" ] ; then
		    # Should be impossible
		    sixdeskmesslevel=0
		    sixdeskmess="You have not selected a platform CPSS, LSF, BOINC or GRID!!!"
		    sixdeskmess
		    sixdesklockdir=$sixdeskstudy
		    sixdeskunlock
		    sixdeskexit 10
		fi
	    else
		# actually submit
		if [ "$sixdeskplatform" == "lsf" ] ; then
		    sixdeskRunnam=$Runnam
		    sixdeskRundir=$Rundir
		    source ${SCRIPTDIR}/bash/dot_bsub $Runnam $Rundir
		elif [ "$sixdeskplatform" == "cpss" ] ; then
		    # The 3rd param 0 means only if not submitted already
		    source ${SCRIPTDIR}/bash/dot_task
		elif [ "$sixdeskplatform" == "boinc" ] ; then
		    # The 3rd param 0 means only if not submitted already
		    source ${SCRIPTDIR}/bash/dot_boinc
		fi
            fi

        done
	# end of loop over angles
    done
    # end of loop over amplitudes
}

function treatDA(){
    Angle=0
    kk=0
    
    # get dirs for this point in scan (returns Runnam, Rundir, actualDirName)
    sixdeskDefinePointTree $LHCDesName $iMad "d" $sixdesktunes $Ampl "0" $Angle $kk $sixdesktrack

    if ${lprepare} ; then
	# does rundir exist?
	submitCreateRundir $RundirFullPath

	# finalise generation of fort.3
	sed -e 's/%NO/'$NO'/g' \
            -e 's/%tunex/'$tunexx'/g' \
            -e 's/%tuney/'$tuneyy'/g' \
            -e 's/%inttunex/'$inttunexx'/g' \
            -e 's/%inttuney/'$inttuneyy'/g' \
            -e 's/%Runnam/'$Runnam'/g' \
            -e 's/%NV/'$NV'/g' $sixdeskjobs_logs/fortda.3.mask > $sixdeskjobs_logs/fort.3

	# final preparation of all SIXTRACK files
	submitCreateLinks $RundirFullPath $sixtrack_input $sixdeskjobs_logs
	
	# submission file
	sed -e 's?SIXJOBNAME?'"$Runnam"'?g' \
            -e 's?SIXTRACKDAEXE?'$SIXTRACKDAEXE'?g' \
            -e 's?SIXJOBDIR?'$Rundir'?g' \
            -e 's?SIXTRACKDIR?'$sixdesktrack'?g' \
            -e 's?SIXJUNKTMP?'$sixdeskjobs_logs'?g' $sixdeskhome/utilities/${lsfjobtype}.job > $sixdeskjobs_logs/$Runnam.job
	chmod 755 $sixdeskjobs_logs/$Runnam.job
    else
	# actually submit
	sixdeskRunnam=$Runnam
	sixdeskRundir=$Rundir
	source ${SCRIPTDIR}/bash/dot_bsub $Runnam $Rundir
    fi

}

# ==============================================================================
# main
# ==============================================================================

# ------------------------------------------------------------------------------
# preliminary to any action
# ------------------------------------------------------------------------------
# - get path to scripts (normalised)
if [ -z "${SCRIPTDIR}" ] ; then
    SCRIPTDIR=`dirname $0`
    SCRIPTDIR="`cd ${SCRIPTDIR};pwd`"
    export SCRIPTDIR=`dirname ${SCRIPTDIR}`
fi
# ------------------------------------------------------------------------------

# actions
lprepare=false
lcheck=false
lsubmit=false
lselected=false

# get options (heading ':' to disable the verbose error handling)
while getopts  ":hpscS" opt ; do
    case $opt in
	h)
	    how_to_use
	    exit 1
	    ;;
	p)
	    # prepare simulation files
	    lprepare=true
	    # check
	    lcheck=true
	    ;;
	c)
	    # check only
	    lcheck=true
	    ;;
	s)
	    # check
	    lcheck=true
	    # submit
	    lsubmit=true
	    ;;
	S)
	    # selected points of scan only
	    lselected=true
	    ;;
	:)
	    how_to_use
	    echo "Option -$OPTARG requires an argument."
	    exit 1
	    ;;
	\?)
	    how_to_use
	    echo "Invalid option: -$OPTARG"
	    exit 1
	    ;;
    esac
done
shift "$(($OPTIND - 1))"
# user's request
if ! ${lprepare} && ! ${lsubmit} && ! ${lcheck} ; then
    how_to_use
    echo "No action specified!!! aborting..."
    exit
elif ${lprepare} && ${lsubmit} ; then
    how_to_use
    echo "Please choose only one action!!! aborting..."
    exit
fi

# ------------------------------------------------------------------------------
# preparatory steps
# ------------------------------------------------------------------------------

# - load environment
source ${SCRIPTDIR}/bash/dot_env
# - settings for sixdeskmessages
sixdeskmessleveldef=0
sixdeskmesslevel=$sixdeskmessleveldef
# - define user tree
sixdeskDefineUserTree $basedir $scratchdir $workspace

# - preliminary checks
preliminaryChecks

# - notify user
sixdeskmesslevel=2
sixdeskmess="Using sixtrack_input ${sixtrack_input}"
sixdeskmess
sixdeskmess="Using ${sixdeskjobs_logs}"
sixdeskmess
sixdeskmesslevel=$sixdeskmessleveldef

# - lock study dir
sixdesklockdir=$sixdeskstudy
sixdesklock

# - square hard-coded?!
square=0

# ------------------------------------------------------------------------------
# actual operations
# ------------------------------------------------------------------------------

# - tunes
sixdeskmess="Main loop for Study $LHCDescrip, Seeds $ista to $iend"
sixdeskmess
sixdesktunes
if [ $long -eq 1 ] ; then
    sixdeskmess="Amplitudes $ns1l to $ns2l by $nsincl, Angles $kinil, $kendl, $kmaxl by $kstep"
    sixdeskmess
elif [ $short -eq 1 ] || [ $da -eq 1 ] ; then
    sixdeskmess="Amplitudes $ns1s to $ns2s by $nss, Angles $kini, $kend, $kmax by $kstep"
    sixdeskmess
fi

# preparation to main loop
if ${lprepare} ; then
    # - these dirs should already exist...
    mkdir -p $sixdesktrack
    mkdir -p $sixdeskjobs_logs
    mkdir -p $sixdesktrackStudy
    # - save emittance and gamma
    echo "$emit  $gamma" > $sixdesktrackStudy/general_input
    # - set up of fort.3
    for tmpFile in fort.3.mad fort.3.mother1 fort.3.mother2 ; do
	cp ${sixtrack_input}/${tmpFile} $sixdeskjobs_logs
	if [ $? -ne 0 ] ; then
	    sixdeskmess="unable to copy ${sixtrack_input}/${tmpFile} to $sixdeskjobs_logs"
	    sixdeskmess
	    sixdeskexit 1
	fi
    done
    # - set CHROVAL and TUNEVAL
    if [ $chrom -eq 0 ] ; then
        CHROVAL='/'
    else
        CHROVAL=''
    fi
    if [ $tune -eq 0 ] ; then
	TUNEVAL='/'
    else
	TUNEVAL=''
    fi
    preProcessFort3
    # - specific to type of run
    if [ $short -eq 1 ] ; then
	preProcessShort
    elif [ $da -eq 1 ] ; then
	preProcessDA
    fi
fi
if ${lcheck} ; then
    lerr=0
    # - general_input
    inspectPrerequisites $sixdesktrackStudy -s general_input
    # - preProcessFort3
    inspectPrerequisites ${sixdeskjobs_logs} -s fort0.3.mask forts.3.mask fortl.3.mask fortda.3.mask
    if [ $short -eq 1 ] ; then
	if [ $sussix -eq 1 ] ; then
	    inspectPrerequisites ${sixdeskjobs_logs} -s sussix.tmp.1 sussix.tmp.2 sussix.tmp.3
	fi
	inspectPrerequisites ${sixdeskjobs_logs} -s ${lsfjobtype}.job ${lsfjobtype}0.job
    elif [ $da -eq 1 ] ; then
	inspectPrerequisites ${sixdeskjobs_logs} -s dalie.data dalie.input dalie reson.data readda
    fi
    if [ ${lerr} -gt 0 ] ; then
        sixdeskmess="Preparatory step failed."
        sixdeskmess
        sixdesklockdir=$sixdeskstudy
        sixdeskunlock
        sixdeskexit 49
    fi
fi
# - echo emittance and dimsus
factor=`gawk 'END{fac=sqrt('$emit'/'$gamma');print fac}' /dev/null`
dimsus=`gawk 'END{dimsus='$dimen'/2;print dimsus}' /dev/null` 
sixdeskmess="factor $factor - dimsus $dimsus"
sixdeskmess
# - touch some files related to monitoring of submission of jobs
if ${lsubmit} ; then
    touch $sixdeskwork/completed_cases
    touch $sixdeskwork/mycompleted_cases
    touch $sixdeskwork/incomplete_cases
    touch $sixdeskwork/myincomplete_cases
    touch $sixdeskwork/taskids
    touch $sixdeskjobs/jobs
    touch $sixdeskjobs/incomplete_jobs
fi

# main loop
for (( iMad=$ista; iMad<=$iend; iMad++ )) ; do
    itunexx=$itunex
    ituneyy=$ituney
    if test $ideltax -eq 0 -a $ideltay -eq 0 ; then
	ideltax=1000000
	ideltay=1000000
    fi
    while test $itunexx -le $itunex1 -o $ituneyy -le $ituney1 ; do
	# - get $sixdesktunes
	sixdesklooptunes
	#   ...notify user
	sixdeskmess="Tunescan $sixdesktunes"
	sixdeskmess
	# - get simul path (storage of beta values), stored in $Rundir...
	sixdeskDefinePointTree $LHCDesName $iMad "s" $sixdesktunes "" "" "" "" $sixdesktrack
	# - int tunes
	sixdeskinttunes
	# - beta values?
	if [ $short -eq 1 ] || [ $long -eq 1 ] ; then
	    if ${lprepare} ; then
		mkdir -p $RundirFullPath
		cd $sixdeskjobs_logs
		if [ $chrom -eq 0 ] ; then
		    sixdeskmess="Running two one turn jobs to compute chromaticity"
		    sixdeskmess
		    submitChromaJobs $RundirFullPath
		else
		    sixdeskmess="Using Chromaticity specified as $chromx $chromy"
		    sixdeskmess
		fi
		sixdeskmess="Running `basename $SIXTRACKEXE` (one turn) to get beta values"
		sixdeskmess
		submitBetaJob $RundirFullPath
		cd $sixdeskhome
	    fi
	    if ${lcheck} ; then
		# checks
		lerr=0
		inspectPrerequisites $RundirFullPath -d ""
		if [ $chrom -eq 0 ] ; then
		    inspectPrerequisites $RundirFullPath -s mychrom
		fi
		inspectPrerequisites $RundirFullPath -s betavalues
		if [ ${lerr} -gt 0 ] ; then
		    sixdeskmess="Failure in preparation."
		    sixdeskmess
		    sixdesklockdir=$sixdeskstudy
		    sixdeskunlock
		    sixdeskexit 48
		fi
	    fi
	    parseBetaValues $RundirFullPath
	fi
	
	# Resonance Calculation only
	N1=0
	if [ $N1 -gt 0 ] ; then
	    N2=9
	    Qx=63.28
	    Qy=59.31
	    nsr=10.
	    Ax=`gawk 'END{Ax='$nsr'*sqrt('$emit'/'$gamma'*'$beta_x');print Ax}' /dev/null`
	    Ay=`gawk 'END{Ay='$nsr'*sqrt('$emit'/'$gamma'*'$beta_y');print Ay}' /dev/null`
	    echo "$Qx $Qy $Ax $Ay $N1 $N2" > $sixdeskjobs_logs/resonance
	fi
	
	# actually submit according to type of job
	if [ $short -eq 1 ] ; then
	    treatShort
	elif [ $long -eq 1 ] ; then
	    treatLong
	elif [ $da -eq 1 ] ; then
	    treatDA
	fi
	
	# get ready for new point in tune
	itunexx=`expr $itunexx + $ideltax`
	ituneyy=`expr $ituneyy + $ideltay`
    done
done

# ------------------------------------------------------------------------------
# go home, man
# ------------------------------------------------------------------------------

# echo that everything went fine
sixdeskmess="Completed normally"
sixdeskmess

# bye bye
sixdeskexit 0