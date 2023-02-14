local httpService = gameGetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.ValueToHex() }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]SetValueRGB(Color3.fromHex(data.value))
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { type = 'KeyPicker', idx = idx, mode = object.Mode, key = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]SetValue({ data.key, data.mode })
				end
			end,
		}
	}

	function SaveManagerSetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManagerSetFolder(folder)
		self.Folder = folder;
		selfBuildFolderTree()
	end

	function SaveManagerSave(name)
		local fullPath = self.Folder .. 'settings' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManagerLoad(name)
		local file = self.Folder .. 'settings' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				self.Parser[option.type].Load(option.idx, option)
			end
		end

		return true
	end

	function SaveManagerIgnoreThemeSettings()
		selfSetIgnoreIndexes({ 
			BackgroundColor, MainColor, AccentColor, OutlineColor, FontColor, -- themes
			ThemeManager_ThemeList, 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
	end

	function SaveManagerBuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. 'themes',
			self.Folder .. 'settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManagerRefreshConfigList()
		local list = listfiles(self.Folder .. 'settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if filesub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = filefind('.json', 1, true)
				local start = pos

				local char = filesub(pos, pos)
				while char ~= '' and char ~= '' and char ~= '' do
					pos = pos - 1
					char = filesub(pos, pos)
				end

				if char == '' or char == '' then
					table.insert(out, filesub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManagerSetLibrary(library)
		self.Library = library
	end

	function SaveManagerLoadAutoloadConfig()
		if isfile(self.Folder .. 'settingsautoload.txt') then
			local name = readfile(self.Folder .. 'settingsautoload.txt')

			local success, err = selfLoad(name)
			if not success then
				return self.LibraryNotify('Failed to load autoload config ' .. err)
			end

			self.LibraryNotify(string.format('Auto loaded config %q', name))
		end
	end


	function SaveManagerBuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = tabAddRightGroupbox('Configuration')

		sectionAddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = selfRefreshConfigList(), AllowNull = true })
		sectionAddInput('SaveManager_ConfigName',    { Text = 'Config name' })

		sectionAddDivider()

		sectionAddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value

			if namegsub(' ', '') == '' then 
				return self.LibraryNotify('Invalid config name (empty)', 2)
			end

			local success, err = selfSave(name)
			if not success then
				return self.LibraryNotify('Failed to save config ' .. err)
			end

			self.LibraryNotify(string.format('Created config %q', name))

			Options.SaveManager_ConfigList.Values = selfRefreshConfigList()
			Options.SaveManager_ConfigListSetValues()
			Options.SaveManager_ConfigListSetValue(nil)
		end)AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = selfLoad(name)
			if not success then
				return self.LibraryNotify('Failed to load config ' .. err)
			end

			self.LibraryNotify(string.format('Loaded config %q', name))
		end)

		sectionAddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value

			local success, err = selfSave(name)
			if not success then
				return self.LibraryNotify('Failed to overwrite config ' .. err)
			end

			self.LibraryNotify(string.format('Overwrote config %q', name))
		end)
		
		sectionAddButton('Autoload config', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. 'settingsautoload.txt', name)
			SaveManager.AutoloadLabelSetText('Current autoload config ' .. name)
			self.LibraryNotify(string.format('Set %q to auto load', name))
		end)

		sectionAddButton('Refresh config list', function()
			Options.SaveManager_ConfigList.Values = selfRefreshConfigList()
			Options.SaveManager_ConfigListSetValues()
			Options.SaveManager_ConfigListSetValue(nil)
		end)

		SaveManager.AutoloadLabel = sectionAddLabel('Current autoload config none', true)

		if isfile(self.Folder .. 'settingsautoload.txt') then
			local name = readfile(self.Folder .. 'settingsautoload.txt')
			SaveManager.AutoloadLabelSetText('Current autoload config ' .. name)
		end

		SaveManagerSetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManagerBuildFolderTree()
end

return SaveManager