#!/bin/bash
for ugly_shell_script in $( find . -name '*\.sh' )
do 
    echo -n "Syntax Check for ${ugly_shell_script}: "
    bash -n ${ugly_shell_script}
    if [[ $? -eq 0 ]]
    then 
        echo OK
    else 
        echo ERROR
    fi
done
