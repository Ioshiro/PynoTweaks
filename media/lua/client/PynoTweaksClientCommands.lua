require("survivalRewards")
-- local characterManagement = {}
local pageBook = {}
local timedBook = {}
-- local activityCalendar = {}
local playerBkp = {}
if getActivatedMods():contains("Erase&Rewind_RPGbyVorshim") then
-- characterManagement = require('character/CharacterManagement')
pageBook = require('book/PageBook')
-- timedBook = require('book/TimedBook')
-- activityCalendar = require('lib/ActivityCalendar')
    if getActivatedMods():contains("Erase&Rewind_BKP") then
        playerBkp = require('CharacterPlayer')
    end
end

-- gestione dei comandi ricevuti dal server
local function OnServerCommand(module, command, arguments)
    if module == "Pyno" then
        if command == "killyno" then
            local kills = arguments.kills
            local hours = arguments.hours
            local steamID = arguments.steamID
            local player = getPlayerByOnlineID(steamID)
            player:setZombieKills(kills)
            player:setHoursSurvived(hours)
            if SandboxVars.PynoTweaks.SyncRewards then
                for i, v in ipairs(hourMilestones) do
                    if hours >= v then
                        player:getModData().milReached = i
                    end
                end

                for i, v in ipairs(killMilestones) do
                    if kills >= v then
                        player:getModData().kilMilReached = i
                    end
                end
            end
            player:Say("Lesgoo") 
        elseif command == "reppyno" then
            local setOrAdd = arguments.setOrAdd
            local factioncode = arguments.factioncode
            local amount = arguments.amount
            local steamID = arguments.steamID
            local player = getPlayerByOnlineID(steamID)

            if setOrAdd == "set" then
                player:getModData().missionProgress.Factions[1].reputation = amount
                SF_MissionPanel.instance.needsUpdate = true
                SF_MissionPanel.instance.needsBackup = true
            elseif setOrAdd == "add" then
                SF_MissionPanel:awardReputation(factioncode, amount)
            elseif setOrAdd == "remove" then
                SF_MissionPanel:removeReputation(factioncode, amount)
            end
            
            player:Say("Reputazione aggiornata!")
        elseif command == "questyno" then
            local addOrComplete = arguments.addOrComplete
            local questID = arguments.questID
            local steamID = arguments.steamID
            local player = getPlayerByOnlineID(steamID)

            if addOrComplete == "add" then
                SF_MissionPanel:unlockQuest(questID)
            elseif addOrComplete == "complete" then
                SF_MissionPanel:completeQuest(player, questID)
            elseif addOrComplete == "backup" then
                SF_MissionPanel:forceBackupData()
            elseif addOrComplete == "remove" then
                SF_MissionPanel.Commands.removequest(questID)
            end

            player:Say("Missione aggiornata!")

        elseif command == "zombyno" then
            local command = arguments.command
            local steamID = arguments.steamID
            local player = getPlayerByOnlineID(steamID)
            if command == "conto" then
                if #player:getModData().missionProgress.ActionEvent == 0 then
                    player:Say("Non ho altri zombie da ammazzare.")
                end
                for k, v in pairs(player:getModData().missionProgress.ActionEvent) do
                    local zcount = tonumber(luautils.split(v.condition, ";")[2])
                    local npcname = luautils.split(v.commands, ";")[2]
                    -- trim numbers at the end of the string and add _Name
                    npcname = "IGUI_SFQuest_" .. string.gsub(npcname, "%d+$", "") .. "_Name"
                    local count = player:getZombieKills()
                    local toKill = zcount - count
                    npcname = getText(npcname)
                    player:Say("Devo uccidere altri " .. toKill .. " zombie per " .. npcname .. ".")
                end
            end
        elseif command == "fixxyno" then
            local steamID = arguments.steamID
            local player = getPlayerByOnlineID(steamID)
            command = arguments.command
            if command == "rerolldaily" then
                SF_MissionPanel.instance.DailyEventReroll() --Expanded

            elseif command == "loadbackup" then
                local flag = arguments.checkDefaults
                if flag then
                    sendClientCommand(player, 'SFQuest', 'sendData', {id = arguments.id})
                end
            elseif command == "lincolnreed" then
                local factions = player:getModData().missionProgress.Factions
                table.insert(factions, {factioncode = "LincolnReed", name = "IGUI_SFQuest_LincolnReed_Name", reputation = 99, repmax = 100, tierlevel = 3, tiername = "IGUI_SFQuest_Questyno_LincolnReed_Tier3", tiercolor = "green", itemindex = 41, height = 36, index = 41})
                player:getModData().missionProgress.Factions = factions
                SF_MissionPanel.instance.needsUpdate = true
                SF_MissionPanel.instance.needsBackup = true
            elseif command == "updatefrequency" then
                local oldfrequency = tonumber(arguments.oldfrequency)
                local newfrequency = tonumber(arguments.newfrequency)
                local dailyEvents = player:getModData().missionProgress.DailyEvent
                for k, v in pairs(dailyEvents) do
                    if v.frequency == oldfrequency then
                        v.frequency = newfrequency
                    end
                end
                player:getModData().missionProgress.DailyEvent = dailyEvents
                SF_MissionPanel.instance.needsUpdate = true
                SF_MissionPanel.instance.needsBackup = true
            end
        elseif command == "libryno" then
            local steamID = arguments.steamID
            local player = getPlayerByOnlineID(steamID)
            print("command " .. arguments.command .. " steamID " .. steamID .. " player " .. player:getUsername())
            local bookType = arguments.bookType
            print("bookType: " .. tostring(bookType))

            local modData_Table = nil
            local modData_Name = arguments.modDataName
            if bookType == "READ_ONCE_BOOK" then
                modData_Table = pageBook.ReadOnceBook
            elseif bookType == "TIMED_BOOK" then
                modData_Table = pageBook.TimedBook
            elseif bookType == "BKP_MOD_1" then
                modData_Table = playerBkp.BKP_1
            elseif bookType == "BKP_MOD_2" then
                modData_Table = playerBkp.BKP_2
            else
                print("Errore: modData_Table non riconosciuto - " .. tostring(bookType))
                return
            end

            local subCommand = arguments.command
            if subCommand == "delete" or subCommand == "remove" then
                local message = nil
                if arguments.done then
                    message = "Il backup " .. bookType .. " è stato cancellato per il player " .. player:getUsername()
                elseif not arguments.done then
                    message = "Il libro non esiste " .. bookType .. " per il player " .. player:getUsername()
                end
                getPlayer():Say(message)

            elseif subCommand == "restore" then
                -- characterManagement.requestBackupData(modData_Name)
                if arguments.done then
                    getPlayer():Say("Il backup " .. bookType .. " è stato ripristinato per il player " .. player:getUsername())
                else
                    getPlayer():Say("Il libro  " .. bookType .. " non è stato ripristinato per il player " .. player:getUsername())
                end
            elseif subCommand == "backup" then
                -- characterManagement.writeBook(player, modData_Table, modData_Name)
            if arguments.success then
                getPlayer():Say("Il backup " .. bookType .. " è stato salvato per il player " .. player:getUsername())
            else 
                getPlayer():Say("Il libro  " .. bookType .. " non è stato salvato per il player " .. player:getUsername())
            end
            elseif subCommand == "check" then
                local message = nil
                if arguments.exists then
                    message = "Il backup " .. bookType .. " esiste per il player " .. player:getUsername()
                elseif not arguments.exists then
                    message = "Il libro non esiste " .. bookType .. " per il player " .. player:getUsername()
                end
                getPlayer():Say(message)
            else
                print("Errore: comando non riconosciuto - " .. tostring(subCommand))
            end
        end
    end
end


Events.OnServerCommand.Add(OnServerCommand)