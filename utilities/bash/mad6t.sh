#!/bin/bash

function how_to_use() {
    cat <<EOF

   `basename $0` [action] [option]
   to manage madx jobs for generating input files for sixtrack

   actions (mandatory, one of the following):
   -c      check
   -s      submit
              in this case, madx jobs are submitted to lsf

   options (optional):
   -i      madx is run interactively (ie on the node you are locally
              connected to, no submission to lsf at all)
           option available only for submission, not for checking
   -d      study name (when running many jobs in parallel)
   -o      define output (preferred over the definition of sixdesklevel in sixdeskenv)
               0: only error messages and basic output 
               1: full output
               2: extended output for debugging

EOF
}

function preliminaryChecksM6T(){
    # some sanity checks
    local __lerr=0
    
    if [ ! -s $maskFilesPath/$LHCDescrip.mask ] ; then
	# error: mask file not present
	sixdeskmess -1 "$LHCDescrip.mask is required in sixjobs/mask !!! "
	let __lerr+=1
    fi
    if [ ! -d "$sixtrack_input" ] ; then
	# error: $sixtrack_input directory does not exist
	sixdeskmess -1 "The $sixtrack_input directory does not exist!!!"
	let __lerr+=1
    fi
    if test "$beam" = "" -o "$beam" = "b1" -o "$beam" = "B1" ; then
	appendbeam=''
    elif test "$beam" = "b2" -o "$beam" = "B2" ; then
	appendbeam='_b2'
    else
	# error: unrecognised beam option
	sixdeskmess -1 "Unrecognised beam option $beam : must be null, b1, B1, b2 or B2!!!"
	let __lerr+=1
    fi
    if [ ${__lerr} -gt 0 ] ; then
	exit ${__lerr}
    fi
    
    return $__lerr
}

function submit(){
    # useful echo
    # - madx version and path
    sixdeskmess  1 "Using madx Version $MADX in $MADX_PATH"
    # - Study, Runtype, Seeds
    echo
    sixdeskmess -1 "STUDY          ${LHCDescrip}"
    sixdeskmess -1 "RUNTYPE        ${runtype}"
    sixdeskmess -1 "SEEDS          [${istamad}:${iendmad}]"
    echo
    # - interactive madx
    if ${linter}  ; then
	sixdeskmess 1 "Interactive MADX runs"
    fi

    # copy templates...
    cp $controlFilesPath/fort.3.mother1_${runtype} $sixtrack_input/fort.3.mother1.tmp
    cp $controlFilesPath/fort.3.mother2_${runtype}${appendbeam} $sixtrack_input/fort.3.mother2.tmp

    # ...and make sure we set the optional value for the proton mass
    sed -i -e 's?%pmass?'$pmass'?g' \
	   -e 's?%emit_beam?'$emit_beam'?g' \
	   $sixtrack_input/fort.3.mother1.tmp

    # ...take care of crossing angle in bbLens, in case appropriate
    xing_rad=0
    if [ -n "${xing}" ] ; then 
	# variable is defined
	xing_rad=`echo "$xing" | awk '{print ($1*1E-06)}'`
	sixdeskmess  1 " --> crossing defined: $xing ${xing_rad}"
	sed -i -e 's?%xing?'$xing_rad'?g' \
  	    -e 's?/ bb_ho5b1_0?bb_ho5b1_0?g' \
	    -e 's?/ bb_ho1b1_0?bb_ho5b1_0?g' $sixtrack_input/fort.3.mother1.tmp
    fi
     
    # Clear flags for checking
    for tmpFile in CORR_TEST ERRORS WARNINGS ; do
	rm -f $sixtrack_input/$tmpFile
    done

    sixdeskmktmpdir mad $sixtrack_input
    export junktmp=$sixdesktmpdir
    sixdeskmess 1 "Using junktmp: $junktmp"
    
    cd $junktmp
    filejob=$LHCDescrip
    cp $maskFilesPath/$filejob.mask .

    # Loop over seeds
    mad6tjob=$lsfFilesPath/mad6t1.lsf
    for (( iMad=$istamad ; iMad<=$iendmad ; iMad++ )) ; do
	
	# clean away any existing results for this seed
	for f in 2 8 16 34 ; do
	    rm -f $sixtrack_input/fort.$f"_"$iMad.gz
	done
    
	sed -e 's?%NPART?'$bunch_charge'?g' \
	    -e 's?%EMIT_BEAM?'$emit_beam'?g' \
	    -e 's?%SEEDSYS?'$iMad'?g' \
	    -e 's?%SEEDRAN?'$iMad'?g' $filejob.mask > $filejob."$iMad"
	sed -e 's?%SIXJUNKTMP%?'$junktmp'?g' \
	    -e 's?%SIXI%?'$iMad'?g' \
	    -e 's?%SIXFILEJOB%?'$filejob'?g' \
	    -e 's?%CORR_TEST%?'$CORR_TEST'?g' \
	    -e 's?%FORT_34%?'$fort_34'?g' \
	    -e 's?%MADX_PATH%?'$MADX_PATH'?g' \
	    -e 's?%MADX%?'$MADX'?g' \
	    -e 's?%SIXTRACK_INPUT%?'$sixtrack_input'?g' $mad6tjob > mad6t_"$iMad".lsf
	chmod 755 mad6t_"$iMad".lsf

	if ${linter} ; then
	    sixdeskmktmpdir batch ""
	    cd $sixdesktmpdir
	    ../mad6t_"$iMad".lsf | tee $junktmp/"${LHCDescrip}_mad6t_$iMad".log 2>&1
	    cd ../
	    rm -rf $sixdesktmpdir
	else
	    read BSUBOUT <<< $(bsub -q $madlsfq -o $junktmp/"${LHCDescrip}_mad6t_$iMad".log -J ${workspace}_${LHCDescrip}_mad6t_$iMad mad6t_"$iMad".lsf)
	    tmpString=$(printf "Seed %2i        %40s\n" ${iMad} "${BSUBOUT}")
	    sixdeskmess -1 "${tmpString}"
	fi
	mad6tjob=$lsfFilesPath/mad6t.lsf
    done

    # End loop over seeds
    cd $sixdeskhome
}

function check_output_option(){
    local __selected_output_valid
    __selected_output_valid=false
    
    case ${OPTARG} in
    ''|*[!0-2]*) __selected_output_valid=false ;;
    *)           __selected_output_valid=true  ;;
    esac

    if ! ${__selected_output_valid}; then
	echo "ERROR: Option -o requires the following arguments:"
	echo "    0: only error messages and basic output [default]"
	echo "    1: full output"
	echo "    2: extended output for debugging"
	exit
    else
	loutform=true
	sixdesklevel_option=${OPTARG}
    fi
    
}


function check(){
    sixdeskmess 1 "Checking MADX runs for study $LHCDescrip in ${sixtrack_input}"
    local __lerr=0
    # accepted discrepancy in file dimensions [%]
    local __factor=1
    
    # check jobs still running
    nJobs=`bjobs -w | grep ${workspace}_${LHCDescrip}_mad6t | wc -l`
    if [ ${nJobs} -gt 0 ] ; then
	bjobs -w | grep ${workspace}_${LHCDescrip}_mad6t
	sixdeskmess -1 "There appear to be some mad6t jobs still not finished"
	let __lerr+=1
    fi
    
    # check errors/warnings
    if [ -s $sixtrack_input/ERRORS ] ; then
	sixdeskmess -1 "There appear to be some MADX errors!"
	sixdeskmess -1 "If these messages are annoying you and you have checked them carefully then"
	sixdeskmess -1 "just remove sixtrack_input/ERRORS or rm sixtrack_input/* and rerun `basename $0` -s!"
	echo "ERRORS"
	cat $sixtrack_input/ERRORS
	let __lerr+=1
    elif [ -s $sixtrack_input/WARNINGS ] ; then
	sixdeskmess -1 "There appear to be some MADX result warnings!"
	sixdeskmess -1 "Some files are being changed; details in sixtrack_input/WARNINGS"
	sixdeskmess -1 "If these messages are annoying you and you have checked them carefully then"
	sixdeskmess -1 "just remove sixtrack_input/WARNINGS"
	echo "WARNINGS"
	cat $sixtrack_input/WARNINGS
	let __lerr+=1
    fi

    # check generated files
    let njobs=$iendmad-$istamad+1
    iForts="2 8 16"
    if [ "$fort_34" != "" ] ; then
	iForts="${iForts} 34"
    fi
    for iFort in ${iForts} ; do
	# - the expected number of files have been generated
	nFort=0
	sixdeskmess 1 "Checking that a fort.${iFort}_??.gz exists for each MADX seed requested..."
	for (( iMad=${istamad}; iMad<=${iendmad}; iMad++ )) ; do
	    let nFort+=`ls -1 $sixtrack_input/fort.${iFort}_${iMad}.gz 2> /dev/null | wc -l`
	done
	if [ ${nFort} -ne ${njobs} ] ; then
	    sixdeskmess -1 "Discrepancy!!! Found ${nFort} fort.${iFort}_??.gz (expected $njobs)"
	    let __lerr+=1
	    continue
	else
	    sixdeskmess -1 "...found ${nFort} fort.${iFort}_??.gz (as expected)"
	fi
        # - files are all of comparable dimensions
	tmpFilesDimensions=`\ls -l $sixtrack_input/fort.${iFort}_*.gz 2> /dev/null | awk '{print ($5,$9)}'`
	tmpFiles=`echo "${tmpFilesDimensions}" | awk '{print ($2)}'`
	tmpFiles=( ${tmpFiles} )
	tmpDimens=`echo "${tmpFilesDimensions}" | awk '{print ($1)}'`
	tmpAve=`echo "${tmpDimens}" | awk '{tot+=$1}END{print (tot/NR)}'`
	tmpSig=`echo "${tmpDimens}" | awk -v "ave=${tmpAve}" '{tot+=($1-ave)**2}END{print (sqrt(tot)/NR)}'`
	sixdeskmess -1 "   average dimension (kB): ${tmpAve} - sigma (kB): ${tmpSig}"
	if [ `echo ${tmpAve} | awk '{print ($1==0)}'` -eq 1 ] ; then
	    sixdeskmess -1 "   --> NULL average file dimension!! Maybe something wrong with MADX runs?"
	    let __lerr+=1
	elif [ `echo ${tmpAve} ${tmpSig} ${__factor} | awk '{print ($2<$1*$3/100)}'` -eq 0 ] ; then
	    sixdeskmess -1 "   --> spread in file dimensions larger than ${__factor} % !! Maybe something wrong with MADX runs?"
	    let __lerr+=1
	else
	    tmpDimens=( ${tmpDimens} )
	    for (( ii=0; ii<${#tmpDimens[@]}; ii++ )) ; do
		if [ `echo ${tmpDimens[$ii]} ${tmpAve} ${__factor} | awk '{diff=($1/$2-1); if (diff<0) {diff=-diff} ; print(diff<$3/100)}'` -eq 0 ] ; then
		    sixdeskmess -1 "   --> dimension of file `basename ${tmpFiles[$ii]}` is different from average by more than ${__factor} % !!"
		    let __lerr+=1
		fi
	    done
	fi
    done

    # check mother files
    if test ! -s $sixtrack_input/fort.3.mother1 \
	    -o ! -s $sixtrack_input/fort.3.mother2
    then
	sixdeskmess -1 "Could not find fort.3.mother1/2 in $sixtrack_input"
	let __lerr+=1
    else
	sixdeskmess 1 "all mother files are there"
    fi

    # multipole errors
    if test "$CORR_TEST" -ne 0 -a ! -s "$sixtrack_input/CORR_TEST"
    then
	sixdeskmiss=0
	for tmpCorr in MCSSX MCOSX MCOX MCSX MCTX ; do
	    rm -f $sixtrack_input/${tmpCorr}_errors
	    for (( iMad=$istamad; iMad<=$iendmad; iMad++ )) ; do
		ls $sixtrack_input/$tmpCorr"_errors_"$iMad
		if [ -f $sixtrack_input/$tmpCorr"_errors_"$iMad ] ; then
		    cat  $sixtrack_input/$tmpCorr"_errors_"$iMad >> $sixtrack_input/$tmpCorr"_errors"
		else
		    let sixdeskmiss+=1
		fi
	    done
	done
	if [ $sixdeskmiss -eq 0 ] ; then
	    echo "CORR_TEST MC_error files copied" > $sixtrack_input/CORR_TEST
	    sixdeskmess 1 "CORR_TEST MC_error files copied"
	else
	    sixdeskmess -1 "$sixdeskmiss MC_error files could not be found!!!"
	    let __lerr+=1
	fi
    fi

    if [ ${__lerr} -gt 0 ] ; then
	# final remarks
	sixdeskmess 1 "Problems with MADX runs!"
	exit ${__lerr}
    else
	# final remarks
	sixdeskmess 1 "All the mad6t jobs appear to have completed successfully using madx -X Version $MADX in $MADX_PATH"
	sixdeskmess 1 "Please check the sixtrack_input directory as the mad6t runs may have failed and just produced empty files!!!"
	sixdeskmess 1 "All jobs/logs/output are in sixtrack_input/mad.mad6t.sh* directories"
    fi
    return $__lerr
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

# initialisation of local vars
linter=false
lsub=false
lcheck=false
loutform=false
currStudy=""
optArgCurrStudy="-s"

# get options (heading ':' to disable the verbose error handling)
while getopts  ":hiso:cd:" opt ; do
    case $opt in
	h)
	    how_to_use
	    exit 1
	    ;;
	i)
	    # interactive mode of running
	    linter=true
	    ;;
	c)
	    # required checking
	    lcheck=true
	    ;;
	s)
	    # required submission
	    lsub=true
	    ;;
	o)
	    # required submission
	    check_output_option
	    ;;	
	d)
	    # the user is requesting a specific study
	    currStudy="${OPTARG}"
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
# user's requests:
# - actions
if ! ${lcheck} && ! ${lsub} ; then
    how_to_use
    echo "No action specified!!! aborting..."
    exit 1
elif ${lcheck} && ${lsub} ; then
    how_to_use
    echo "Please choose only one action!!! aborting..."
    exit 1
elif ${lcheck} && ${linter} ; then
    echo "Interactive mode valid only for running. Switching it off!!!"
    linter=false
fi
# - options
if [ -n "${currStudy}" ] ; then
    optArgCurrStudy="-d ${currStudy}"
fi

# load environment
# NB: workaround to get getopts working properly in sourced script
OPTIND=1
source ${SCRIPTDIR}/bash/set_env.sh ${optArgCurrStudy} -e
if ${loutform} ; then
    sixdesklevel=${sixdesklevel_option}
fi
# build paths
sixDeskDefineMADXTree ${SCRIPTDIR}

# define trap
trap "sixdeskexit 1" EXIT

# don't use this script in case of BNL
if test "$BNL" != "" ; then
    sixdeskmess -1 "Use prepare_bnl instead for BNL runs!!! aborting..."
    sixdeskexit 1
fi

if ${lsub} ; then
    # - some checks
    preliminaryChecksM6T

    # - define locking dirs
    lockingDirs=( "$sixdeskstudy" "$sixtrack_input" )

    # - lock dirs before doing any action
    for tmpDir in ${lockingDirs[@]} ; do
	sixdesklock $tmpDir
    done
    
    # - define trap
    trap "sixdeskCleanExit 1" EXIT

    submit

    # - redefine trap
    trap "sixdeskCleanExit 0" EXIT

else
    check
    # - redefine trap
    trap "sixdeskexit 0" EXIT
fi

# echo that everything went fine

sixdeskmess -1 "               Appears to have completed normally"
echo 
# bye bye
exit 0
