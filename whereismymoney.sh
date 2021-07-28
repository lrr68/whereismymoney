#!/bin/sh

#-Script to deal with personal finances.
#-Keeps track of how much money you have by logging how much you spent and received.
#-Money spent is saved as a negative value, while money received is saved as a positive value.

BANKFILE="$HOME/.bank.csv"
HEADER="date time,amount,transaction type"
DEFAULT_EXPENSE="basic expenses"
DEFAULT_RECEIVE="paycheck"

logtransaction()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return
	[ ! "$2" ] && echo "ERROR: Transaction type not informed" && return

	DATE=$(date "+%Y-%m-%d %H:%M")
	AMOUNT="$1"; shift
	TRANSACTION_TYPE="$1"; shift

	echo "$DATE,$AMOUNT,$TRANSACTION_TYPE" >> $BANKFILE
}

logmoneyspent()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return

	TRANSACTION_TYPE="$DEFAULT_EXPENSE"
	AMOUNT="$1"; shift
	#make sure it's a negative
	[ "${AMOUNT:0:1}" = '-' ] || AMOUNT="-$AMOUNT"

	[ "$1" ] && TRANSACTION_TYPE="$1" && shift

	logtransaction "$AMOUNT" "$TRANSACTION_TYPE"
}

logmoneyreceived()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return

	TRANSACTION_TYPE="$DEFAULT_RECEIVE"
	AMOUNT="$1"; shift
	#make sure it's a positive
	[ "${AMOUNT:0:1}" = '-' ] && AMOUNT="${AMOUNT:1}"

	[ "$2" ] && TRANSACTION_TYPE="$2" && shift

	logtransaction "$AMOUNT" "$TRANSACTION_TYPE"
}

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
