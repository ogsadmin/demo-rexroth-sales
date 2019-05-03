
function XTRACE() end
function AddDllDirectory() end


require('monitor')
require('custom_folder/modbus_gui')




create_station_result("GB402", "192.168.1.110","19.11.2014 13:24:50","info","müller","pycha","OK");
create_part_result("GB402", 1, "teil_1","19.11.2014 13:20:45","OK");
create_bolt_result("GB402", 1, 1, "S1","Nexo-GB402",1,14.696,14,15,764,600,1000,"OK", 1, 1012, 12345678, 'OP1');

	local 	xmlText
	local   FileName

	FileName , xmlText = MBGetJSON('GB402', 1,1)

	print (FileName)

	print ('\n-------------------------------------\n')

    print (xmlText)





