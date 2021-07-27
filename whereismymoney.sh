#!/bin/sh

#-Script to deal with personal finances.
#-Keeps track of how much money you have by logging how much you spent and received.
#-Money spent is saved as a negative value, while money received is saved as a positive value.

BANKFILE="$HOME/.bank.csv"
HEADER="date time,value,transaction type"
DEFAULT_TRANSACTION_TYPE="basic expenses"

showbankfile()
{
	column -s',' -t < $BANKFILE
}

#RUNNING
[ -a "$BANKFILE" ] ||
	echo "$HEADER" > $BANKFILE

case "$1" in
	spent) shift
		logmoneyspent $1
		;;
	received) shift
		logmoneyreceived $1
		;;
	show)
		showbankfile
		;;
	*)
		echo "usage: ${0##*/} ( command )"
		echo "commands:"
		echo "		spent (number) [ type ]: Register an expense of number and type (if informed)"
		echo "		received (number) [ type ]: Register you received number and type (if informed)"
		echo "		show: Shows the bankfile"
		;;
esac
