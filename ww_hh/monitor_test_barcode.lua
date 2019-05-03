require('monitor')



BarCode_Init()
BarCode_Reset()
print(BarCode_AddNew('12345678'))
print(BarCode_AddNew('12345678901234567'))

x = {}
x = BarCode_GetTable()

if #(x[1].val) == 8 and #(x[2].val) == 17 then
	print(x[1].val .. x[2].val)
end

print(BarCode_GetPartID())

print "end!"
