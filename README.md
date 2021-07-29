# whereismymoney

Script to deal with personal finances.
Keeps track of how much money you have by logging how much you spent and received.
Money spent is saved as a negative value, while money received is saved as a positive value.

## Usage:
I advise you put this script in a place you PATH can reach so you can just run ```whereismymoney( command )```

### commands:
#### balance [ i ]
Get current balance. if i is passed, interactively select which transactions to count.
#### spend (number) [ type ]
Register an expense of amount (number) and type (if informed).
#### receive (number) [ type ]
Register you received an amount of (number) and type (if informed).
#### show
Shows the bankfile.
#### fetch
Gets transactions registered remotelly by email.
To propperly use this command you must configure the EMAIL and SUBJECT variables and have access to a server running dovecot.
The EMAIL variable should be set for <username>@<server>, this username and server should reflect a user that has an email account on server <server>.
The SUBJECT variable should be set to the subject of the emails that you will send that contain a whereismymoney command.
Each email can contain multiple whereismymoney ```spend``` and ```receive``` commands, each in it's own line.
Pay attention as the syntax must be correct for the commands to work.
If no command is detected inside a email this will be logged to ```$HOME/.whereismymoney.log``` and notified via notify-send.

## TODO:
+ Make it more POSIX compliant by removing ```IFS=$'\n'```
+ Use while loops to read files line by line instead of the current clumsy for
