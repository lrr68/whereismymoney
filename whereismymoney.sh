#!/bin/sh

#-Script to deal with personal finances.
#-Keeps track of how much money you have by logging how much you spent and received.
#-Money spent is saved as a negative value, while money received is saved as a positive value.

bankfile="$HOME/Documents/bank.csv"
monthly_transactions_file="$HOME/Documents/monthly_transactions.csv"
header="date time,amount,transaction type"
monthly_header="type, amount, description"
default_expense="basic expenses"
default_receive="paycheck"
currency="R$"

#subject is used to filter emails that contain commands
subject="Whereismymoney"
#email is used to ssh to server and fetch remote commands
email="sua@mae.com"

cur_date=""

addmonthly()
{
	[ ! "$1" ] && echo "Inform type" && return
	t_type="$1"; shift

	[ ! "$1" ] && echo "Inform value" && return
	value="$1"; shift

	[ ! "$1" ] && echo "Inform description" && return
	description="$1"; shift

	[ -e "$monthly_transactions_file" ] || echo "$monthly_header" > "$monthly_transactions_file"

	[ ! "$t_type" = "income" ] && [ ! "$t_type" = "expense" ] &&
			echo "Type not reconized. Valid types are 'income' or 'expense'" && return

	#expenses are negative
	if [ "$t_type" = "income" ]
	then
		value="${value#-}"
	else
		value="-${value#-}"
	fi

	echo "$t_type,$value,$description" >> "$monthly_transactions_file"
}

showmonthly()
{
	[ -e "$monthly_transactions_file" ] ||
		echo "$monthly_header" > "$monthly_transactions_file"

	column -s',' -t < "$monthly_transactions_file"
	showmonthlytotals
}

showmonthlytotals()
{
	[ -e "$monthly_transactions_file" ] ||
		echo "$monthly_header" > "$monthly_transactions_file"

	total_in=$(awk -F',' 'NR>1 && $1 == "income" {total+=$2;}END{print total;}' "$monthly_transactions_file")
	total_ex=$(awk -F',' 'NR>1 && $1 == "expense" {total+=$2;}END{print total;}' "$monthly_transactions_file")
	[ "$total_in" ] && echo "You receive $currency$total_in every month."
	[ "$total_ex" ] && echo "You Spend $currency$total_ex every month."
	[ ! "$total_ex" ] && [ ! "$total_in" ] && echo "No Monthly expenses"
}

fetchupdates()
{
	cur_date=$(date "+%Y-%m-%d %H:%M")
	fetchmonthlytransactions
	fetchemailtransactions
}

fetchmonthlytransactions()
{
	cur_month=${cur_date%-*}
	#also remove 0 so number is not treated as octal
	cur_month=${cur_month#*-0}
	last_month=$(tail -n 1 "$bankfile")
	last_month=${last_month%% *}
	last_month=${last_month%-*}
	#also remove 0 so number is not treated as octal
	last_month=${last_month#*-0}

	[ ! "$cur_month" -gt "$last_month" ] && return

	while IFS= read -r transaction || [ -n "$transaction" ]
	do
		[ "$transaction" = "$monthly_header" ] && continue

		amount="${transaction#*,}"
		amount="${amount%,*}"

		if [ "${transaction%%,*}" = "income" ]
		then
			logmoneyreceived "$amount" "${transaction##*,}"
		else
			logmoneyspent "$amount" "${transaction##*,}"
		fi
	done < "$monthly_transactions_file"
}

fetchemailtransactions()
{
	state=0
	cmd=""
	amount=""
	t_type=""
	body=""
	mailquery="${0##*/}.mailquery"

	(ssh $email "doveadm fetch 'body date.received' mailbox inbox subject $subject > mailquery &&
		doveadm flags add '\Seen' mailbox inbox unseen subject $subject &&
		doveadm move Trash mailbox inbox seen subject $subject &&
		cat mailquery" > "$mailquery")
	# query the server for unseen emails with subject=$subject
	# outputs email body and date.received to a file so line breaks are preserved
	# marks these emails as seen
	# cats the file so we get it's contents locally
	while IFS= read -r line || [ -n "$line" ]
	do
		case "$state" in
			0) #expect body
				[ "${line%%:*}" = "body" ] && state=1
				;;
			1) #read until find spend or receive
				#concatenate line for future error reporting
				body="$body|$line"
				if [ "${line%% *}" = "Spend" ] ||
					[ "${line%% *}" = "Receive" ]
				then
					state=2
					cmd="${line%% *}"
					amount="${line#* }"
					amount="${amount%% *}"
					t_type="${line#* }"
					t_type="${t_type#* }"
				elif [ "${line%%:*}" = "date.received" ]
				then
					#read until date and did not get command, something is wrong with the email
					{
						echo "${0##*/} ERROR:"
						echo "    Command not found in email"
						echo "    body: $body"
						echo "====Please do this one manually"
					} >> "$HOME/.${0##*/}.log"

					state=0
					body=""
				fi
				;;
			2) #read until find date.received
				if [ "${line%%:*}" = "date.received" ]
				then
					# change global date variable to email date so it's saved with the right timestamp
					cur_date="${line#*: }"
					#remove seconds to match bankfile FORMAT
					cur_date="${cur_date%:*}"
					[ "$cmd" = "Spend" ] && logmoneyspent "$amount" "$t_type"
					[ "$cmd" = "Receive" ] && logmoneyreceived "$amount" "$t_type"
					#Reset to read next
					state=0
					body=""
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

	amount="$1"; shift
	t_type="$1"; shift

	echo "$cur_date,$amount,$t_type" >> "$bankfile"
}

logmoneyspent()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return

	t_type="$default_expense"
	amount="$1"; shift
	#make sure it's a negative
	amount="-${amount#-}"

	[ "$1" ] && t_type="$1" && shift

	logtransaction "$amount" "$t_type"
}

logmoneyreceived()
{
	[ ! "$1" ] && echo "ERROR: Amount not informed" && return

	t_type="$default_receive"
	amount="$1"; shift
	#make sure it's a positive
	amount="${amount#-}"

	[ "$1" ] && t_type="$1" && shift

	logtransaction "$amount" "$t_type"
}

getbalance()
{
	total=$(awk -F',' 'NR>1 {total+=$2;}END{print total;}' "$bankfile")

	if [ "${total%.*}" -lt 0 ]
	then
		echo "You have a debt of -$currency${total#-}"
	else
		echo "You have $currency$total"
	fi
}

showbankfile()
{
	column -s',' -t < "$bankfile"
	getbalance
}

#RUNNING
[ -e "$bankfile" ] ||
	echo "$header" > "$bankfile"

case "$1" in
	add) shift
		addmonthly "$1" "$2" "$3"
		;;
	balance) shift
		getbalance
		;;
	edit) shift
		"$EDITOR" "$bankfile"
		;;
	editm) shift
		"$EDITOR" "$monthly_transactions_file"
		;;
	fetch) shift
		fetchupdates
		;;
	receive) shift
		cur_date=$(date "+%Y-%m-%d %H:%M")
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
		cur_date=$(date "+%Y-%m-%d %H:%M")
		logmoneyspent "$1" "$2"
		;;
	*)
		echo "usage: ${0##*/} ( command )"
		echo "commands:"
		echo "		add (income/expense) (number) (description): adds a montly expense or income,"
		echo "			every month it will be put automatically on the csv file."
		echo "		edit: Opens the bankfile with EDITOR"
		echo "		editm: Opens the monthly transactions file with EDITOR"
		echo "		spend (number) [ type ]: Register an expense of number and type (if informed)"
		echo "		receive (number) [ type ]: Register you received number and type (if informed)"
		echo "		fetch: Fetches transactions registered by email and monthly transactions if due"
		echo "		show: Shows the bankfile"
		echo "		showm: Shows the monthly expenses file"
		echo "		showmt: Shows the sum of your monthly expenses and incomes"
		;;
esac
