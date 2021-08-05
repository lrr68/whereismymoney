# whereismymoney

Script to deal with personal finances.
Keeps track of how much money you have by logging how much you spent and received.
Money spent is saved as a negative value, while money received is saved as a positive value.

## Usage:
I advise you put this script in a place you PATH can reach so you can just run ```whereismymoney( command )```

### commands:
#### add (income/expense) (number) (description)
Adds a monthly transaction of type income or expense, with value of ```number```. When you run the fetch command if the last logged transaction was from the previous month, these monthly transactions will be logged automatically.
#### balance [ i ]
Get current balance. if i is passed, interactively select which transactions to count.
#### edit
Opens the bankfile with EDITOR.
#### editm
Opens the monthly transactions file with EDITOR.
#### spend (number) [ type ]
Register an expense of amount (number) and type (if informed).
#### receive (number) [ type ]
Register you received an amount of (number) and type (if informed).
#### show
Shows the bankfile.
#### showm
Shows the monthly transactions file.
#### showmt
Shows the monthly transactions total sum.
#### fetch
This fetch command does two things: Gets transactions registered remotelly by email and gets transactions registered as monthly transactions. The monthly transactions are registered as mentioned in the ```add``` command.
To propperly use this command you must configure the EMAIL and SUBJECT variables and have access to a server running dovecot.
The EMAIL variable should be set for <username>@<server>, this username and server should reflect a user that has an email account on server <server>.
The SUBJECT variable should be set to the subject of the emails that you will send that contain a whereismymoney command.
Each email can contain only one whereismymoney ```spend``` or ```receive``` command, in a single line.
Pay attention as the syntax must be correct for the commands to work.
If no command is detected inside a email this will be logged to ```$HOME/.whereismymoney.log``` and notified via notify-send.

## TODO:
+ Improve readme
+ Improve overall compatibility by checking for the binaries of external programs such as notify-send
