-- Locals
local fs 			= require("filesystem")
local term 			= require("term")
local serialization = require("serialization")
local event 		= require("event")
local colors 		= require("colors")
local shell			= require("shell")

local component = require 'component'
local os 		= require 'os'
local sides 	= require 'sides'
local math		= require 'math'
local rs	= component.redstone
local tur 	= component.br_turbine
local react = component.br_reactor
local gpu 	= component.gpu
--local fs	= filesystem
local config = {}
local reactor = nil
local running = true
local screen = "main"
local Optimum
local Timer = false
local Pause = false

function Turbine1800 ()
	local Goal = 1800.0
	local variance = 0.1
	local Percentage
	local x, y = term.getCursor()
	gpu.setBackground(0xffffff)
	gpu.fill(9,35,82,6, " ")
	gpu.setBackground(0x000000)
	term.setCursor(10, 33)
	print("Richte Turbine aus...")

	while tur.getRotorSpeed() < (Goal-variance) or tur.getRotorSpeed() > (Goal+variance) do
		if tur.getRotorSpeed() < (Goal-variance-100) then
			tur.setFluidFlowRateMax(2000)
			tur.setInductorEngaged(false)
		elseif tur.getRotorSpeed() < (Goal-variance) then
			tur.setFluidFlowRateMax(1000)
			tur.setInductorEngaged(false)
		elseif tur.getRotorSpeed() > (Goal+variance) then
			tur.setFluidFlowRateMax(200) --Anpassen an Coil Material
			tur.setInductorEngaged(true)
		elseif tur.getRotorSpeed() > (Goal+variance+100) then
			tur.setFluidFlowRateMax(0)
			tur.setInductorEngaged(true)
		elseif tur.getRotorSpeed() > 2000 then
			tur.setFluidFlowRateMax(0)
			tur.setInductorEngaged(true)
		end
		--gpu.setBackground(0xffffff)
		--gpu.fill(19,35,62,10, " ")
		gpu.setBackground(0x25004a)
		if tur.getRotorSpeed() < 1800 then
			Percentage = (tur.getRotorSpeed()/1800) else
			Percentage = 1 - ((tur.getRotorSpeed()-1800)/1800)
		end
		gpu.fill(10,36,80 * Percentage ,4, " ")
		gpu.setBackground(0x000000)
		GuiHeadUpdate()

		if rs.getInput(sides.west) > 10		--terminator
		then
			gracefulEnd()
		end
	end
	gpu.setBackground(0x25004a)
	gpu.fill(9,33,82,8, " ")
	term.setCursor(x,y)
end

function Startup ()
	gpu.setBackground(0x25004a)
	print("Turbine hochfahren...")
	react.setAllControlRodLevels(0)
	tur.setInductorEngaged(false)
	Turbine1800()
	tur.setInductorEngaged(true)
	react.setAllControlRodLevels(20)
	print("Turbine erfolgreich hochgefahren!")
end

function FindIdeal ()
	gpu.setBackground(0x25004a)
	Startup()
	print("Messung Beginnt...")
	local SpeedBegin = tur.getRotorSpeed()
	local SpeedEnd = 999999
	local Delta = 0.1
	local Rotation = LoadOptimum
	local precision = false

	while not precision and (math.abs(SpeedEnd - SpeedBegin) > Delta) do
		Turbine1800()
		SpeedBegin = tur.getRotorSpeed()
		tur.setFluidFlowRateMax(Rotation)
		os.sleep(20)
		SpeedEnd = tur.getRotorSpeed()
		print("Rotation: " .. Rotation .. " Differenz : " .. (SpeedEnd - SpeedBegin))
		if (math.abs(SpeedEnd - SpeedBegin) > Delta) then
			RotationNext = round(Rotation - (SpeedEnd - SpeedBegin) * 3)--Anpassen an Größenordnung
			if RotationNext == Rotation then precision = true end
			Rotation = RotationNext
		end
	end
	print("Turbine Kalibiert")
	return Rotation
end

function runReacturbine ()
	print("Beginne Betrieb")

	Speed = event.timer(0.1, AdjustTurbineSpeed, math.huge)
	Rods = event.timer(0.5, AdjustControlRods, math.huge)

	Reds = event.listen("redstone_changed", RSInput)

	Update = event.timer(0.1, GuiUpdate, math.huge)
end

function AdjustTurbineSpeed()
	if tur.getRotorSpeed() < 1780 -- Zu langsam ?
	then
		tur.setFluidFlowRateMax(1500)
		tur.setInductorEngaged(false)
	end

	if (tur.getRotorSpeed() >= 1780 and not tur.getInductorEngaged())
	then
		tur.setInductorEngaged(true)
	end

	if tur.getInductorEngaged()
	then
		if tur.getRotorSpeed() > 1805
			then tur.setFluidFlowRateMax(Optimum - 1)
		end

		if tur.getRotorSpeed() < 1795
			then tur.setFluidFlowRateMax(Optimum + 1)
		end
	end
end

function AdjustControlRods()
	local tmp = react.getCasingTemperature()
	if (tmp < 200) --and not timer
	then react.setAllControlRodLevels(react.getControlRodLevel(0) - 10/ round(react.getNumberOfControlRods()))
	os.sleep(0.5)
	elseif (tmp < 250)
	then react.setAllControlRodLevels(react.getControlRodLevel(0) - 5 / round(react.getNumberOfControlRods()))
	os.sleep(0.5)
	elseif (tmp < 260)
	then react.setAllControlRodLevels(react.getControlRodLevel(0) - 1)
	os.sleep(0.5)
	elseif tmp > 350 --and not timer
	then react.setAllControlRodLevels(react.getControlRodLevel(0) + 10/ round(react.getNumberOfControlRods()))
	os.sleep(0.5)
	elseif tmp > 300 --and not timer
	then react.setAllControlRodLevels(react.getControlRodLevel(0) + 5 / round(react.getNumberOfControlRods()))
	os.sleep(0.5)
	elseif tmp > 290 --and not timer
	then react.setAllControlRodLevels(react.getControlRodLevel(0) + 1)
	os.sleep(0.5)
	end
end

function pause()
	if Pause then
		tur.setActive(true)
		react.setActive(true)
		Turbine1800()
		tur.setFluidFlowRateMax(Optimum)
		tur.setInductorEngaged(true)
		Speed = event.timer(0.1, AdjustTurbineSpeed, math.huge)
		Rods = event.timer(0.5, AdjustControlRods, math.huge)
		Pause = false
		print("Betrieb wird fortgesetzt.")
	else
		event.cancel(Speed)
		event.cancel(Rods)
		tur.setActive(false)
		react.setActive(false)
		tur.setInductorEngaged(false)
		Pause = true
		print("Betrieb ist angehalten.")
	end
end

function gracefulEnd()
	print("Programm beendet")
	event.cancel(Speed)
	event.cancel(Rods)
	event.cancel(Reds)
	event.cancel(Update)
	event.ignore("touch",listen)
	running = false
	tur.setActive(false)
	tur.setInductorEngaged(false)
	react.setActive(false)
	term.setCursor(1,49)
	gpu.setBackground(0x000000)
	os.exit()
end

function RSInput()
	if rs.getInput(sides.west) > 10		--terminator
	then
		gracefulEnd()
	end
end

function UnTimer()
	print("Timer Ende")
	timer = false
end

function GuiMake()
	term.clear()
	gpu.setBackground(0x000000)
	gpu.fill(1,1,100,1, " ")
	gpu.setBackground(0x25004a)
	gpu.fill(1,2,100, 49, " ")
	gpu.setBackground(0x000099)
	gpu.fill(1,48,12, 3, " ")
	term.setCursor(4,49)
	print("Pause")
	gpu.setBackground(0x990000)
	gpu.fill(89,48,12, 3, " ")
	term.setCursor(93,49)
	print("Exit")
	gpu.setBackground(0x000000)
	term.setCursor(1,50)
end

function GuiHeadUpdate()
	local StatusTur
	local StatusReact
	local x,y = term.getCursor()

	if   tur.getConnected() then StatusTur   = "online" else StatusTur   = "offline" end
	if react.getConnected() then StatusReact = "online" else StatusReact = "offline" end


	--header
	rstring =      "Reaktor: " .. StatusReact .. "  Temperatur: " .. round(react.getCasingTemperature()) .."C    "
	tstring = "    Turbine: " .. StatusTur .. "  Rotation: " .. round(tur.getRotorSpeed() / 1800 * 100) .."%"

	gpu.setBackground(0x000000)
	term.setCursor(1,1)
	print(rstring)
	term.setCursor(100 - string.len(tstring),1)
	print(tstring)
	gpu.setBackground(0x25004a)
	term.setCursor(x,y)
end

function GuiUpdate()
	local StatusRod
	local x,y = term.getCursor()
	local StatusTreibstoff

	StatusRod = react.getControlRodLevel(0) / 100
	StatusTreibstoff = react.getFuelAmount() / react.getFuelAmountMax()

	--header
	GuiHeadUpdate()

	--Treibstoffanzeige
	gpu.setBackground(0x25004a)
	term.setCursor(3, 34)
	print("Treibstoff Status: ".. round(StatusTreibstoff*100) .. "% ")
	gpu.setBackground(0xff0000)
	gpu.fill(2,36,98,1, " ")
	gpu.setBackground(0x00ff00)
	gpu.fill(2,36,98 * StatusTreibstoff,1, " ")

	--Bremsstabanzeige
	gpu.setBackground(0x25004a)
	term.setCursor(3, 38)
	print("Bremsstab Status: " .. StatusRod*100 .. "% ")
	gpu.setBackground(0xffffff)
	gpu.fill(2,40,98,5, " ")
	gpu.setBackground(0x25004a)
	gpu.fill(3,41,96 * StatusRod,3, " ")
	term.setCursor(x,y)
end

function LadeDatei()
	file = io.open("Optimum.txt", "r")
	io.input(file)
	LoadOptimum = tonumber(io.read())
	--LoadOptimum = 1010
	io.close(file)
end

--506

function listen(name,address,x,y,button,player) --Buttons
	component.computer.beep()
	if between(89,x,100,48,y,50) then
		gracefulEnd()
	elseif between(1,x,13,48,y,50) then
		pause()
	end
end

function between (x1, x, x2, y1, y, y2)
	return x1 < x and x < x2 and y1 < y and y < y2
end

function round (Zahl)
	return math.floor(Zahl + 0.5)
end

function round2(T, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(T * mult + 0.5) / mult
end


Touch = event.listen("touch",listen)
local Args, Opts = shell.parse(...)



GuiMake()
term.setCursor(1,3)
gpu.setResolution(100,50)
LadeDatei()

tur.setActive(true)
react.setActive(true)

if Opts["nofind"] then
	Optimum = LoadOptimum
	Startup() else
	Optimum = FindIdeal()
end

runReacturbine()
