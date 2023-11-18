# RCLootCouncilFilter

With Dragonflight's new loot system, [RCLootCouncil](https://www.curseforge.com/wow/addons/rclootcouncil) will automatically pass on all loot and allow the master looter to handle distribution. This system is great and seamless for Guild based progression raids where raid leads will manage things for the team. However, in public groups this can easily lead to unknowing raiders giving their loot to a random group's raid lead. **RCLootCouncil** currently reactivates itself on each app launch, so even if a raider disables it, logging in again will potentially cause a problem again.


**RCLootCouncilFilter** provides some additional filter settings to toggle when **RCLootCouncil** will be enabled. Specifically, when entering a raid instance it will check the **RCLootCouncilFilter** settings and instance conditions to:

- **Auto-enable RCLootCouncil**, if joining a `Normal`, `Heroic` or `Mythic` instance (can be configured) that is lead by your guild. This is similar to **RCLootCouncil** today where it is enabled for each raid progression night.
- **Prompt to enable RCLootCouncil for the instance**, if joining a `Mythic` instance (can be configured) that is not lead by your guild.
- **Auto-disable RCLootCouncil**, if the raid difficulty doesn't match settings (`Normal`, `Heroic` by default) to avoid giving away loot by accident.


This add-on only adds some additional quality of life features for Dragonflight raiders on top of the existing amazing **[RCLootCouncil](https://www.curseforge.com/wow/addons/rclootcouncil)** add-on. Please refer to the [RCLootCouncil](https://www.curseforge.com/wow/addons/rclootcouncil) add-on details for how to support them.

[Latest Release](https://github.com/goines/RCLootCouncilFilter/releases/latest)
