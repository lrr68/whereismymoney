#!/bin/sh

#-Script to deal with personal finances.
#-Keeps track of how much money you have by logging how much you spent and received.
#-Money spent is saved as a negative value, while money received is saved as a positive value.

BANKFILE="$HOME/Documents/.bank.csv"
MONTHLY_TRANSACTIONS_FILE="$HOME/Documents/.monthly_transactions.csv"
HEADER="date time,amount,transaction type"
MONTHLY_HEADER="type, amount, description"
DEFAULT_EXPENSE="basic expenses"
DEFAULT_RECEIVE="paycheck"
CURRENCY="R$"

#SUBJECT is used to filter emails that contain commands
SUBJECT="Whereismymoney"
#EMAIL is used to ssh to server and fetch remote commands
EMAIL="sua@mae.com"

DATE=""

addmonthly()
{
	[ ! "$1" ] && echo "Inform type" && return
	TYPE="$1"; shift

	[ ! "$1" ] && echo "Inform value" && return
	VALUE="$1"; shift

	[ ! "$1" ] && echo "Inform description" && return
	DESC="$1"; shift

	[ -e "$MONTHLY_TRANSACTIONS_FILE" ] || echo "$MONTHLY_HEADER" > "$MONTHLY_TRANSACTIONS_FILE"

	[ ! "$TYPE" = "income" ] && [ ! "$TYPE" = "expense" ] &&
			echo "Type not reconized. Valid types are 'income' or 'expense'" && return

	#expenses are negative
	if [ "$TYPE" = "income" ]
	then
		VALUE="${VALUE#-}"
	else
		VALUE="-${VALUE#-}"
	fi

	echo "$TYPE, $VALUE, $DESC" >> "$MONTHLY_TRANSACTIONS_FILE"
}

showmonthly()
{
	[ -e "$MONTHLY_TRANSACTIONS_FILE" ] ||
		echo "$MONTHLY_HEADER" > "$MONTHLY_TRANSACTIONS_FILE"

	column -s',' -t < "$MONTHLY_TRANSACTIONS_FILE"
	showmonthlytotals
}

showmonthlytotals()
{
	[ -e "$MONTHLY_TRANSACTIONS_FILE" ] ||
		echo "$MONTHLY_HEADER" > "$MONTHLY_TRANSACTIONS_FILE"

	TOTAL_IN=$(awk -F',' 'NR>1 && $1 == "income" {total+=$2;}END{print total;}' "$MONTHLY_TRANSACTIONS_FILE")
	TOTAL_EX=$(awk -F',' 'NR>1 && $1 == "expense" {total+=$2;}END{print total;}' "$MONTHLY_TRANSACTIONS_FILE")
	[ "$TOTAL_IN" ] && echo "You receive $CURRENCY$TOTAL_IN every month."
	[ "$TOTAL_EX" ] && echo "You Spend $CURRENCY$TOTAL_EX every month."
	[ ! "$TOTAL_EX" ] && [ ! "$TOTAL_IN" ] && echo "No Monthly expenses"
}

fetchupdates()
{
	fetchmonthlytransactions
	fetchemailtransactions
}

fetchmonthlytransactions()
{
	DATE=$(date "+%Y-%m-%d %H:%M")
	cur_month=${DATE%-*}
	cur_month=${cur_month#*-}
	last_month=$(tail -n 1 "$BANKFILE")
	last_month=${last_month%% *}
	last_month=${last_month%-*}
	last_month=${last_month#*-}
	echo $last_month $MONTH

	if [ "$MONTH" -gt "$last_month" ]
	then
		echo ""
	fi
}

fetchemailtransactions()
{
	STATE=0
	CMD=""
	AMOUNT=""
	TYPE=""
	BODY=""
	mailquery="${0##*/}.mailquery"

	(ssh $EMAIL "doveadm fetch 'body date.received' mailbox inbox unseen SUBJECT $SUBJECT > mailquery &&
		doveadm flags add '\Seen' mailbox inbox unseen SUBJECT $SUBJECT &&
		doveadm move Trash mailbox inbox seen SUBJECT $SUBJECT &&
		cat mailquery" > "$mailquery" 2>&1)
	# query the server for unseen emails with subject=$SUBJECT
	# outputs email body and date.received to a file so line breaks are preserved
	# marks these emails as seen
	# cats the file so we get it's contents locally
	while IFS= read -r line || [ -n "$line" ]
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
					AMOUNT="${AMOUNT%% *}"
					TYPE="${line#* }"
					TYPE="${TYPE#* }"
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

	done < "$mailquery"
	rm "$mailquery"

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

getbalance()
{
	TOTAL=$(awk -F',' 'NR>1 {total+=$2;}END{print total;}' "$BANKFILE")

	if [ "${TOTAL%.*}" -lt 0 ]
	then
		echo "You have a debt of -$CURRENCY${TOTAL#-}"
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
	add) shift
		addmonthly "$1" "$2" "$3"
		;;
	balance) shift
		getbalance
		;;
	edit) shift
		"$EDITOR $BANKFILE"
		;;
	fetch) shift
		fetchupdates
		;;
	receive) shift
		DATE=$(date "+%Y-%m-%d %H:%M")
		logmoneyreceived "$1" "$2"
		;;
	show) shift
		showbankfile
		;;
	showm) shift
		showmonthly
		;;
	showmt) shift
		showmonthlytotals
		;;
	spend) shift
		DATE=$(date "+%Y-%m-%d %H:%M")
		logmoneyspent "$1" "$2"
		;;
	*)
		echo "usage: ${0##*/} ( command )"
		echo "commands:"
		echo "		add (income/expense) (number) (description): adds a montly expense or income,"
		echo "			every month it will be put automatically on the csv file."
		echo "		edit: Opens the bankfile with EDITOR"
		echo "		spend (number) [ type ]: Register an expense of number and type (if informed)"
		echo "		receive (number) [ type ]: Register you received number and type (if informed)"
		echo "		fetch: Fetches transactions registered by email and monthly transactions if due"
		echo "		show: Shows the bankfile"
		echo "		showm: Shows the monthly expenses file"
		echo "		showmt: Shows the sum of your monthly expenses and incomes"
		;;
esac
