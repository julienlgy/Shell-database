# BDSH.sh - Shell DATABASE managing  

Managing JSON database.

usage : `./bdsh -h`

## Example  

```
./bdsh -f testfile.json --save  
./bdsh create database
./bdsh create table user username,password
./bdsh insert user username=julien,password=test
./bdsh -d #display
./bdsh -b #beautify
```