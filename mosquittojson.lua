-- Your access point's SSID and password
local SSID = "greenhouse"
local SSID_PASSWORD = "senhasupersecreta"
local DEVICE = "undefined"
local timesRunned = 0

-- configure ESP as a station
wifi.setmode(wifi.STATION)
wifi.sta.config(SSID,SSID_PASSWORD)
wifi.sta.autoconnect(1)
DEVICE = string.gsub(wifi.sta.getmac(), ":", "")

local HOST = "iot.jeanbrito.com"

function check_wifi()
 local ip = wifi.sta.getip()

 if(ip==nil) then
   print("Connecting...")
 else
  tmr.stop(0)
  print("Connected to AP!")
  print(ip)
  --send_data("15551234567","12223456789","Hello from your ESP8266")
  -- initiate the mqtt client and set keepalive timer to 120sec
  mqtt = mqtt.Client(DEVICE, 120, "", "")

  mqtt:on("connect", function(con)
    print ("connected")
    mqtt_sub()
  end)
  mqtt:on("offline", function(con)
    --print(tmr.now())
    print ("Mqtt Reconnecting...")
    tmr.alarm(1, 1000, 0, function()
        m:connect(HOST, 1883, 0, function(conn)
            print("Mqtt Connected to:" .. HOST)
            mqtt_sub() --run the subscription function
        end)
    end)
end)

  --mqtt:on("message", function(conn, topic, data)
  --  print(topic .. ":" )
  --  if data ~= nil then
  --    print(data)
  --  end
  --end)

  -- on publish message receive event
  mqtt:on("message", function(conn, topic, data)
      print("Recieved:" .. topic .. ":" .. data)
      if (data=="ON") then
          print("Enabling Output")
          gpio.write(1,gpio.HIGH)
          mqtt:publish("greenhouse/actuators/" .. DEVICE .. "/led/state","ON",0,0)
      elseif (data=="OFF") then
          print("Disabling Output")
          gpio.write(1,gpio.LOW)
          mqtt:publish("greenhouse/actuators/" .. DEVICE .. "/led/state","OFF",0,0)
      else
          print("Invalid - Ignoring")
      end
  end)

  function mqtt_sub()
      mqtt:subscribe("greenhouse/actuators/" .. DEVICE .. "/led/control",0, function(conn)
          print("Mqtt Subscribed to OpenHAB feed for device " .. DEVICE)
      end)
  end

  mqtt:connect(HOST, 1883, 0, function(conn)
    print("Connected to broker")
    mqtt_sub()
  -- subscribe topic with qos = 0
    --mqtt:subscribe("sensors/" .. DEVICE .. "/#",0, function(conn)
    -- publish a message with data = my_message, QoS = 0, retain = 0
    -- mqtt:publish("sensors/device002/temperature","67.5",0,0, function(conn)
    -- print("sent")
    -- end)
    --end)
  end)

  tmr.alarm(1,10000,1,sendData)

 end
end

function sendData()

  local t, h = getTempHumi()
  local n = node.heap()
  local times = timesRunned

  timesRunned = timesRunned + 1

  dataString = "temperature=" .. t .. ",humidity=" .. h .. ",runned=" .. times .. ",heap=" .. n

  mqtt:publish("sensors/" .. DEVICE .. "/measurement",dataString,0,0, function(conn)
    print("sent dataString")
  end)

end


tmr.alarm(0,2000,1,check_wifi)

function getTempHumi()
    pin = 4
    local status,temp,humi,temp_decimial,humi_decimial = dht.read(pin)
    if( status == dht.OK ) then
    -- Float firmware using this example
      --print("DHT Temperature:"..temp..";".."Humidity:"..humi)
    elseif( status == dht.ERROR_CHECKSUM ) then
      --print( "DHT Checksum error." );
    elseif( status == dht.ERROR_TIMEOUT ) then
      --print( "DHT Time out." );
    end
    return temp, humi
end
