--[[ 
xyz = {1,2,3,4,5,6,7,8,9,10,11,12}
xx = {}
yy = {}
zz = {}

function split_array_xyr( xyr, x, y, r)
    for i, value in ipairs(xyr) do
        if i % 3 == 1 then
            table.insert(x, value)
        elseif i % 3 == 2 then
            table.insert(y, value)
        else
            table.insert(r, value)
        end
    end
end


split_array_xyr(xyz,
xx,yy,zz)

-- for index, value in ipairs(xx) do
--     print(value.."  "..index)
-- end

-- for index, value in ipairs(yy) do
--     print(value.."  "..index)
-- end

-- for index, value in ipairs(zz) do
--     print(value.."  "..index)
-- end

print("-----------------------------------")
-- Y-报文头
message_header = {"",""}
-- n1-相机序号
camera_number = {0,0}  -- 1-上相机，2-下相机
-- n2-工作模式
operating_mode = {-1,-1}  -- 0-停止，1-标定，2-生产
-- n3-动作模式
action_mode = {0,0}  -- 1-取料，2-放料，3-抛料1，4-抛料2
-- n4-预留位(0)
reserved_variable = {0,0}

-- 初始化空的坐标位置数组
pick_positions = {}
pick_positions_x = {}
pick_positions_y = {}
pick_positions_r = {}

put_positions = {}
put_positions_x = {}
put_positions_y = {}
put_positions_r = {}
--, 1.32,1.236,1.587
msg = {"Y","1","2","1","0", "1.12","1.32","1.236", "1.587","1.32","1.2361587","x2","y2","r2","x3100","y3100","r3100"}

print_modbus_address_value = 1 --将地址打印判断置为 0 (为1打印) 

function print_if_modbus_address_is_1(content_to_print)
    if print_modbus_address_value == 1 then
        print(content_to_print)
    end
    -- 如果不为1，不执行任何打印操作
end

function parse_received_array(received_array,array_num)
    -- 检查数组是否为空
    if #received_array == 0 then
        print_if_modbus_address_is_1("接收到的数组为空")
        return
    end

    -- 遍历数组并打印每个元素
    print_if_modbus_address_is_1("接收到数组")
    
    message_header[array_num] = received_array[1]
    camera_number[array_num] = received_array[2]
    operating_mode[array_num] = received_array[3]
    action_mode[array_num] = received_array[4]
    reserved_variable[array_num] = received_array[5]
    
    if array_num == 1 then
        for i = 6, #received_array do
            pick_positions[i-5] = received_array[i]
        end
        split_array_xyr( pick_positions, pick_positions_x, pick_positions_y, pick_positions_r)
    end
    
    if array_num == 2 then
        for i = 6, #received_array do
            put_positions[i-5] = received_array[i]
        end
        split_array_xyr( put_positions, 
        put_positions_x, 
        put_positions_y, 
        put_positions_r)
    end

end

parse_received_array(msg,1)

for index, value in ipairs(action_mode) do
    print(value.."  "..index)
    -- 如果value为1，则执行取料操作
    if tonumber(value) == 1 then
        print("取料")
    else
        print("放料")
    end
end

for index, value in ipairs(pick_positions_y) do
    print(value.."  "..index)
end

-- for index, value in ipairs(pick_positions_r) do
--     print(value.."  "..index)
-- end



-- 清空数组的函数
function clear_array(arr)
    for i = #arr, 1, -1 do
        arr[i] = 0
    end
end

-- 测试数组
local my_array = {1, 2, 3, 4, 5}

-- 打印原始数组
print("原始数组:", unpack(my_array))

-- 清空数组
clear_array(my_array)

-- 打印清空后的数组
print("清空后的数组:", unpack(my_array))


msg = nil
if msg == nil or #msg == 0 then
    print("msg is nil")
end
 ]]

-- 示例数组
local my_array = {1, 2, 3, 0, 5, 6, 7}

-- 初始化标记
local has_zero = 1

-- 判断数组中是否有值为0
for _, value in ipairs(my_array) do
    if value == 0 then
        has_zero = 0
        break  -- 如果找到了0，就不需要再继续遍历
    end
end

-- 输出结果
if has_zero == 0 then
    print("数组中有值为0")
else
    print("数组中没有值为0")
end

status1 = -1
status2 = -1
num = 0
communication_status = 1
while (status1 ~= 0 or status2 ~= 0) and num < 100 do  --0：连线成功，-1:连线失败，失败后尝试重新连接
    num = num + 1
    print("尝试连接第"..num.."次")
end
if status1 == 0 and status2 == 0 then
    print("连接成功")
else
    print("连接失败")
    communication_status = 0
    print(communication_status)
end
