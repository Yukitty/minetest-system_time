System Clock Daytime [system_time]
==================================

Smoothly synchronize the in-game day/night cycle to a multiple of the server's system clock. Users can join your Minetest server at specific times of day in the real world and experience a consistent and predictable time of day in-game, whether that be hourly or on a full 24 hour cycle.

To configure, just set `time_speed` to the number of day/night cycles in one realtime day and `world_start_time` to the millihour time associated with the start of each cycle (and real-world midnight). The in-game clock will be adjusted automatically.

You may use the `/set` command in-game to see the effects of changing these settings within 5 seconds.

Examples
--------

```
/set time_speed 1
/set world_start_time 0
```

Day/night cycle will be a realtime 24 hour clock synchronized to the server, such that `/time` will tell the accurate real world time.

```
/set time_speed 24
/set world_start_time 6000
```

Day/night cycle will run hourly, with the start of every hour marked by sunrise, and sunset around the half hour. This means that if night time is "dangerous" on your server, players will always know whether it is "safe" to log in or not by just looking at their local clock, regardless of what time zone they're in.

```
/set time_speed 72
/set world_start_time 5250
```

The default settings for Minetest (game and engine). The sun will rise or set around every 10th minute, with midday or midnight around the 5th minute. Changing `world_start_time` to 6000 for a more accurate cycle time (6 am to 6 pm for the daytime 10 minutes) is recommended, but that's up to preference.

Using a significantly higher `time_speed` than 144 is not recommended because the time adjustment mechanics may have trouble keeping up with such a fast clock.

---

No mod dependencies.
Minetest 5.0.0+ only.

Incompatibilities: Will not respect other mods (or server admins) which change the timeofday directly unless `time_speed` is set to 0, eg. Beds will not be able to skip the night cycle. A possible workaround is to adjust `world_start_time` instead; this may become an API feature of the mod in future versions.

[Minetest Forums topic](https://forum.minetest.net/viewtopic.php?f=9&t=22444 "[Mod] System Clock Daytime [system_time] - Minetest Forums")

Copyright © 2019 by Yukita Mayako ("JTE") <catgirl@goddess.moe>

This mod is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published
by the Free Software Foundation, either version 2.1 of the License,
or (at your option) any later version.

This mod is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this mod.  If not,
see <https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html>.
