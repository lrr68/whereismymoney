# whereismymoney

Script to deal with personal finances.
Keeps track of how much money you have by logging how much you spent and received.
Money spent is saved as a negative value, while money received is saved as a positive value.

## Usage:
I advise you put this script in a place you PATH can reach so you can just run ```whereismymoney ( command )```

### commands:
#### add (income/expense) (number) (description):
	adds a monthly expense or income, every month it will be put automatically on the csv file.
#### edit [ group ]:
	Opens the bankfile or group file with EDITOR.
#### editm:
	Opens the monthly transactions file with EDITOR.
#### filter (string):
	Lists expenses containing (string).
#### group (group name) ([-|+] number) (description):
	adds a transaction to the specified group.
#### invest (amount)  (description):
	logs an investment.
#### uninvest (amount)  (description):
	withdraw from invested money.
#### log (group):
	updates the bankfile with the speficied group transactions.
#### receive (number) [ type ]:
	Register you received number and type (if informed).
#### spend (number) [ type ]:
	Register an expense of number and type (if informed).
#### show [ full/monthly/groups/types/typetotal (type)/invested ]:
	shows data from the bank file filtered.

#### fetch
This fetch command does two things: Gets transactions registered remotelly by email and gets transactions registered as monthly transactions. The monthly transactions are registered as mentioned in the ```add``` command.
To propperly use this command you must configure the ```email``` and ```subject``` variables and have access to a server running dovecot.
The ```email``` variable should be set for <username>@<server>, this username and server should reflect a user that has an email account on server <server>.
The ```subject``` variable should be set to the subject of the emails that you will send that contain a whereismymoney command.
Each email can contain only one whereismymoney ```spend``` or ```receive``` command, in a single line.
Pay attention as the syntax must be correct for the commands to work.
If no command is detected inside a email this will be logged to ```$HOME/.whereismymoney.log``` and notified via notify-send.

## TODO:
+ Improve readme
+ Improve overall compatibility by checking for the binaries of external programs such as notify-send
