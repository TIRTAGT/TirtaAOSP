#!/bin/bash
ECHO_BINARY="$(whereis echo | cut -d ' ' -f 2)"

# If $ECHO_BINARY is empty, try using which
if [ -z "$ECHO_BINARY" ]; then
    ECHO_BINARY="$(which echo)"
fi

# If $ECHO_BINARY is still empty, try checking if we have /usr/bin/echo
if [ -z "$ECHO_BINARY" ]; then
    if [ -f "/usr/bin/echo" ]; then
        ECHO_BINARY="/usr/bin/echo"
    fi
fi

# If we cannot find echo, quit now because we cannot setup our custom echo
if [ ! -f "$ECHO_BINARY" ]; then
    echo  -e "\033[1;31mCannot find echo binary, overriding echo is disabled.\033[0m"
else
    echo() {
        # Check if we only have 1 argument, if so, just echo it without any color
        if [ "$#" -eq 1 ]; then
            $ECHO_BINARY "$1"
            return
        fi
        
        # The first parameter must be either "normal", "success", "error", "warning", "info"
        case "$1" in
            "normal")
                $ECHO_BINARY -en "\033[0m"
            ;;
            
            "success")
                $ECHO_BINARY -en "\033[0;32m"
            ;;
            
            "error")
                $ECHO_BINARY -en "\033[1;31m"
            ;;
            
            "warning")
                $ECHO_BINARY -en "\033[0;33m"
            ;;
            
            "info")
                $ECHO_BINARY -en "\033[0;34m"
            ;;
            
            *)
                $ECHO_BINARY "Cannot echo, unknown echo type: $1"
                exit 0
            ;;
        esac
        
        $ECHO_BINARY -n "$2"
        $ECHO_BINARY -e "\033[0m"
    }
fi