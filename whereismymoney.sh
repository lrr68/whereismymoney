#!/bin/sh

#-Script to deal with personal finances.
#-Keeps track of how much money you have by logging how much you spent and received.
#-Money spent is saved as a negative value, while money received is saved as a positive value.

BANKFILE="$HOME/.bank.csv"
HEADER="date time,amount,transaction type"
DEFAULT_EXPENSE="basic expenses"
DEFAULT_RECEIVE="paycheck"
CURRENCY="R$"
#SUBJECT is used to filter emails that contain commands
SUBJECT="Whereismymoney"
#EMAIL is used to ssh to server and fetch remote commands
EMAIL="sua@mae.com"
DATE=""

fetchemailtransactions()
{
	STATE=0
	CMD=""
	AMOUNT=""
	TYPE=""
	BODY=""

	OLDIFS="$IFS"
	IFS=$'\n'

	# query the server for unseen emails with subject=$SUBJECT
	# outputs email body and date.received to a file so line breaks are preserved
	# marks these emails as seen
	# cats the file so we get it's contents locally
	for line in $(ssh $EMAIL "doveadm fetch 'body date.received' mailbox inbox unseen SUBJECT $SUBJECT > mailquery &&
		doveadm flags add '\Seen' mailbox inbox unseen SUBJECT $SUBJECT &&
		cat mailquery")
	do
		case "$STATE" in
			0) #expect body
				[ "${line%%:*}" = "body" ] && STATE=1
				;;
			1) #read until find spend or receive
				#concatenate line for future error reporting
				BODY="$BODY|$line"
				if [ "${line%% *}" = "Spend" ] ||
					[ "${line%% *}" = "Receive" ]
				then
					STATE=2
					CMD="${line%% *}"
					AMOUNT="${line#* }"
					AMOUNT="${AMOUNT% *}"
					TYPE="${line##* }"
				elif [ "${line%%:*}" = "date.received" ]
				then
					#read until date and did not get command, something is wrong with the email
					{
						echo "${0##*/} ERROR:"
						echo "    Command not found in email"
						echo "    BODY: $BODY"
						echo "====Please do this one manually"
					} >> "$HOME/.${0##*/}.log"

					STATE=0
					BODY=""
				fi
				;;
			2) #read until find date.received
				if [ "${line%%:*}" = "date.received" ]
				then
					DATE="${line#*: }"
					#remove seconds to match BANKFILE FORMAT
					DATE="${DATE%:*}"
					[ "$CMD" = "Spend" ] && logmoneyspent "$AMOUNT" "$TYPE"
					[ "$CMD" = "Receive" ] && logmoneyreceived "$AMOUNT" "$TYPE"
					#Reset to read next
					STATE=0
					BODY=""
				fi
				;;
		esac

	done
	IFS="$OLDIFS"

	[ -e "$HOME/.${0##*/}.log" ] &&
		sed 's/|/\n    /g' < "$HOME/.${0##*/}.log" > "$HOME/.${0##*/}.log.aux" &&
		mv "$HOME/.${0##*/}.log.aux" "$HOME/.${0##*/}.log" &&
		notify-send "${0##*/} ERROR" "There were errors processing email logged transactions. See $HOME/.${0##*/}.log"
}

logtransaction()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return
	[ ! "$2" ] && echo "ERROR: Transaction type not informed" && return

	AMOUNT="$1"; shift
	TRANSACTION_TYPE="$1"; shift

	echo "$DATE,$AMOUNT,$TRANSACTION_TYPE" >> "$BANKFILE"
}

logmoneyspent()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return

	TRANSACTION_TYPE="$DEFAULT_EXPENSE"
	AMOUNT="$1"; shift
	#make sure it's a negative
	AMOUNT="-${AMOUNT#-}"

	[ "$1" ] && TRANSACTION_TYPE="$1" && shift

	logtransaction "$AMOUNT" "$TRANSACTION_TYPE"
}

logmoneyreceived()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return

	TRANSACTION_TYPE="$DEFAULT_RECEIVE"
	AMOUNT="$1"; shift
	#make sure it's a positive
	AMOUNT="${AMOUNT#-}"

	[ "$1" ] && TRANSACTION_TYPE="$1" && shift

	logtransaction "$AMOUNT" "$TRANSACTION_TYPE"
}

getbalanceint()
{
	TOTAL=0
	answer=""
	OLDIFS=$IFS
	IFS=$'\n'

	for expense in $(tail -n +2 "$BANKFILE")
	do
		echo "Count $expense? [Y/n]"
		read -r answer

		[ "$answer" = 'n' ] &&
			continue

		amount="${expense%,*}"
		amount="${amount##*,}"

		TOTAL=$(echo $TOTAL "$amount" | awk '{print $1 + $2}')
		echo "total so far: $CURRENCY$TOTAL"
	done
	IFS=$OLDIFS

	if [ "${TOTAL%.*}" -lt 0 ]
	then
		echo "You have a debt of $CURRENCY$TOTAL"
	else
		echo "You have $CURRENCY$TOTAL"
	fi
}

getbalance()
{
	TOTAL=$(awk -F',' 'NR>1 {total+=$2;}END{print total;}' "$BANKFILE")

	if [ "${TOTAL%.*}" -lt 0 ]
	then
		echo "You have a debt of $CURRENCY$TOTAL"
	else
		echo "You have $CURRENCY$TOTAL"
	fi
}

showbankfile()
{
	column -s',' -t < "$BANKFILE"
	getbalance
}

#RUNNING
[ -e "$BANKFILE" ] ||
	echo "$HEADER" > "$BANKFILE"

case "$1" in
	balance) shift
		if [ "$1" = 'i' ]
		then
			getbalanceint
		else
			getbalance
		fi
		;;
	spend) shift
		DATE=$(date "+%Y-%m-%d %H:%M")
		logmoneyspent "$1" "$2"
		;;
	receive) shift
		DATE=$(date "+%Y-%m-%d %H:%M")
		logmoneyreceived "$1" "$2"
		;;
	fetch) shift
		fetchemailtransactions
		;;
	show) shift
		showbankfile
		;;
	*)
		echo "usage: ${0##*/} ( command )"
		echo "commands:"
		echo "		balance [ i ]: Get current balance. if i is passed, select which transactions to count."
		echo "		spend (number) [ type ]: Register an expense of number and type (if informed)"
		echo "		receive (number) [ type ]: Register you received number and type (if informed)"
		echo "		fetch: Gets transactions registered remotelly by email"
		echo "		show: Shows the bankfile"
		;;
esac
