# autoAssist
Should automatically assist a party member who is currently engaged if you aren't already engaged.  
Auto /assist player selection is coming soon (tm)  
  
Should attempt to maintain a distance if approach is on and a range is set. 
Will return to starting position after kills, or the last position set.

## Commands:
```
//autoassist [command] [option]
or
//aa [command] [option]
```
* With no command will toggle autoAssist on/off  
* `on` or `go` or `start` : Will start autoAssist  
* `off` or `stop` or `end` : Will stop autoAssist  
* `assist <player>` : Sets the assist target, this needs to be the capitalized name of the player i.e. Ekrividus not ekrividus  
* `engage` : Sets whether or not to engage target after /assist  
* `approach` : Sets whether or not to approach a target, used with range to determine how close to get 
* `face` : Sets whether or not to automatically face target  
* `fastfollow` or `ffo`: will turn the fastfollow addon on/off using your assist target, this will cause it to follow between mobs
* `follow` or `ft`: will set the target to follow when using fast follow
* `repostiion` or `return` : Sets whether or not to return to start position after fights, position is set to player's position when starting AA or by using
* `position` : Sets the position to return to after a fight, this uses the position the player is standing at when used 
* `range <number>` : Sets range to keep target at, melee range is generally 1~3.5 while max casting range is 21  
* `update <number>` : Sets time between updates in seconds, 0.1 or 1 or 2.5 for instance  
* `show` : Displays current settings  
* `save` : Saves current settings, per character  
* `debug` : If you really want lots of chat spam info  

### Examples
```
//autoassist assist Bojangles
//autoassist range 2.5
//aa update 0.5
//aa engage
```