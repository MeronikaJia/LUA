--Start To Write RL


-------USER   IO定义-------

--USER DI1	伸缩气缸原点1
--USER DI2	伸缩气缸动点1
--USER DI3	伸缩气缸原点2
--USER DI4	伸缩气缸动点2
--USER DI5	伸缩气缸原点3
--USER DI6	伸缩气缸动点3
--USER DI7	伸缩气缸原点4
--USER DI8	伸缩气缸动点4
--USER DI9	机器人去等待位
--USER DI10	机器人去取料位
--USER DI11	机器人去放料位
--USER DI12	机器人去抛料位1
--USER DI13	机器人去抛料位2


--DO1-4: 伸缩气缸1-4
--DO5-8：电磁铁气缸1-4
--DO9：机器人到等待位
--DO10：机器人取料完成
--DO11: 机器人放料完成
--DO12: 机器人抛料完成
-----------------------------


-------报文格式-------
--[[
    Y,n1,n2,n3,n4,
    LX1,LY1,LR1,LX2,LY2,LR2,
    RX1,RY1,RR1,RX2,RY2,RR2
    \r\n


    Y-报文头，
    n1-相机序号(1-上相机，2-下相机)，
    n2-工作模式(0-停止，1-标定，2-生产)，
    n3-动作模式(1-取料，2-放料，3-抛料1，4-抛料2)，
    n4-预留位(0)，
    LX1，LY1，LR1-左鱼钩取放位姿，
    RX1，RY1，RR1-右鱼钩取放位姿
]]
-----------------------------

-- 气缸
DO_airBox = {1,2,3,4}
-- 电磁
DO_electroc = {5,6,7,8}

-- DO9：机器人到等待位
to_waiting_position = 9

-- DO10：机器人取料完成
pick_completed = 10

-- DO11: 机器人放料完成
put_completed = 11

-- DO12: 机器人抛料完成
throw_completed = 12


-- 工具坐标系
tool_coordinate = {1,2,3,4}

-- 气缸原点
DI_air_origin = {1,3,5,7}
-- 气缸动点
DI_air_move = {2,4,6,8}
-- DI9：机器人去等待位
go_waiting_position = 9
-- DI10：机器人去取料位
go_pick_position = 10
-- DI11: 机器人去放料位
go_put_position = 11
-- DI12: 机器人去抛料位1
go_throw_position_1 = 12
-- DI13: 机器人去抛料位2
go_throw_position_2 = 13

-- 安全位
GL_safe_name= "GL_flypick"
-- 下相机拍照位
GL_flypick_name = "GL_flypick"
-- 取料位
GL_pick_name = "GL_pick"
-- 放料位
GL_put_positions = {"GL_put1","GL_put2","GL_put3","GL_put4"}

-- 速度
speed_value = 10

-- 传感器检测
sensor_state = 1
-- 通信状态
communication_status = 1

-- Y-报文头
message_header = {"",""}
-- n1-相机序号
camera_number = {0,0}  -- 1-上相机，2-下相机
-- n2-工作模式
operating_mode = {0,0}  -- 0-停止，1-标定，2-生产
-- n3-动作模式
action_mode = {0,0}  -- 1-取料，2-放料，3-抛料1，4-抛料2
-- n4-预留位(0)   坐标个数
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

-- 存放接收的消息
up_received_message = nil
down_received_message = nil



-- 初始化机器人
function init_robot()
    -- 在此添加初始化代码
    -- IO复位
    reset_digital_output()

    -- 设置速度
    set_speed(speed_value)

    -- 返回到安全位置（GL_safe_name）
    return_to_safe_position(GL_safe_name)

    -- 传感器检测
    sensor_detection()
    -- 通信检测
    communication_connection_detection()

    -- DO到等待位输出
    DO(to_waiting_position, ON)

    print_if_modbus_address_is_1("机器人初始化完成")
end



-- 传感器检测
function sensor_detection()
    set_io_states(DO_airBox, OFF) -- 关闭气缸
    air_origin_state = {} -- 初始化气缸原点状态表
    air_move_state = {} -- 初始化气缸动点状态表
    sensor_state = 1 -- 设置传感器状态为正常
    DELAY(1) -- 延时1秒
    for i = 1, #DI_air_origin do -- 遍历气缸原点输入列表
        if DI(DI_air_origin[i]) == ON then -- 判断气缸原点输入状态是否为ON
            print_if_modbus_address_is_1("检测到气缸原点".. i.. "正常") -- 输出检测到气缸原点正常
            air_origin_state[i] = 1 -- 设置气缸原点状态为正常
        else
            print_if_modbus_address_is_1("检测到气缸原点".. i.. "异常") -- 输出检测到气缸原点异常
            air_origin_state[i] = 0 -- 设置气缸原点状态为异常
            sensor_state = 0 -- 设置传感器状态为异常
        end
    end

    set_io_states(DO_airBox, ON) -- 开启气缸
    DELAY(1) -- 延时1秒
    for i = 1, #DI_air_move do -- 遍历气缸动点输入列表
        if DI(DI_air_move[i]) == ON then -- 判断气缸动点输入状态是否为ON
            print_if_modbus_address_is_1("检测到气缸动点".. i.. "正常") -- 输出检测到气缸动点正常
            air_move_state[i] = 1 -- 设置气缸动点状态为正常
        else
            print_if_modbus_address_is_1("检测到气缸动点".. i.. "异常") -- 输出检测到气缸动点异常
            air_move_state[i] = 0 -- 设置气缸动点状态为异常
            sensor_state = 0 -- 设置传感器状态为异常
        end
    end
    DELAY(1) -- 延时1秒

    set_io_states(DO_airBox, OFF) -- 关闭气缸
end


-- 通讯连接检测
function communication_connection_detection()
    communication_status = 1
    status1 = -1
    status2 = -1
    num = 0
    while (status1 ~= 0 or status2 ~= 0) and num < 100 do  --0：连线成功，-1:连线失败，失败后尝试重新连接
        num = num + 1
        DELAY(0.05)
        PC1,status1=SocketClass(up_camera_server_ip,up_camera_server_port,nil,nil,nil,nil,0.050,false) --左鱼钩字符串
        PC2,status2=SocketClass(down_camera_server_ip,down_camera_server_port,nil,nil,nil,nil,0.050,false) --右鱼钩字符串
    end

    if status1 == 0 and status2 == 0 then
        print_if_modbus_address_is_1("连线成功")
        communication_status = 1
    else
        print_if_modbus_address_is_1("连线失败")
        communication_status = 0
    end
end




-- 打印函数，仅在指定的 Modbus 地址值为 1 时打印指定的内容
print_modbus_address_value = 0 --将地址打印判断置为 0 (为1打印) 

function print_if_modbus_address_is_1(content_to_print)
    if print_modbus_address_value == 1 then
        print(content_to_print)
    end
    -- 如果不为1，不执行任何打印操作
end



-- IO复位
function reset_digital_output()  
	for i=1,12 do
		DO(i,OFF)
	end
	print_if_modbus_address_is_1("复位 DO")
end



-- IO状态设置函数
function set_io_states(io_array, desired_state)
    for i, io_value in ipairs(io_array) do
        DO(io_value,desired_state)
        print_if_modbus_address_is_1("设置 IO" .. io_value .. " 状态为: " .. desired_state)
    end
end



-- 速度设置
function set_speed(rant) --速度,加速度，减速度百分比设定，单位%（0-100）																																																																																																							
  SpdJ(1*rant)
  AccJ(1*rant)
  DecJ(1*rant)
  SpdL(20*rant)
  AccL(250*rant)
  DecL(250*rant)
  print_if_modbus_address_is_1("设置速度为: " .. rant .. "%")
end


-- 回安全位
function return_to_safe_position(point)
	print_if_modbus_address_is_1("正在执行回安全位操作")
	highZ1=RobotZ("Z")
    highZ2=ReadPoint(point,"Z")
    MArchP(point,0,-highZ1,-highZ2)
end

-- 分割数组xyr 到x,y,r
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


-- 解析接收到的数组
function parse_received_array(received_array,array_num)
    -- 检查数组是否为空
    if #received_array == 0 or received_array == nil then
        print_if_modbus_address_is_1("接收到的数组为空")
        return
    end

    print_if_modbus_address_is_1("接收到数组")
    
    message_header[array_num] = received_array[1]
    camera_number[array_num] = tonumber(received_array[2])
    operating_mode[array_num] = tonumber(received_array[3])

    if operating_mode[array_num] == 2 then
        print_if_modbus_address_is_1("生产模式")
        
        action_mode[array_num] = tonumber(received_array[4])
        reserved_variable[array_num] = tonumber(received_array[5])

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
            split_array_xyr( put_positions, put_positions_x, put_positions_y, put_positions_r)
        end
    end
end

function task_put_a_fishhook(GL_put_num, air_num, 
                            electroc, air_origin_num, 
                            air_move_num, x_point, 
                            y_point, r_point)
    
    MArchP( GL_put_num + 
        X(tonumber(x_point)) +
        Y(tonumber(y_point)) +
        RZ(tonumber(r_point)),
        0,50,50
    )
    DELAY(0.2)
    DO(air_num,ON)

    repeat  until DI(air_move_num) == ON
    DO(electroc,OFF)

    DELAY(0.4)
    DO(air_num,OFF)

    repeat  until DI(air_origin_num) == ON
end



function task_put_all_fishhook(fishhook_num)
    Accur("STANDARD")

    for i, value in ipairs(DI_air_origin) do
        WAIT(DI, value, ON)
    end

    for i = 1, fishhook_num do
        task_put_a_fishhook(GL_put_positions[i], DO_airBox[i], 
                            DO_electroc[i], DI_air_origin[i], 
                            DI_air_move[i], put_positions_x[i], 
                            put_positions_y[i], put_positions_r[i])
    end

    Accur("ROUGH")
end



function task_pick_a_fishhook(tool_num, air_num, 
                            electroc, air_origin_num, 
                            air_move_num, x_point, 
                            y_point, r_point, GL_pick_name)
    ChangeTF(tool_num)

    MArchP( GL_pick_name + 
            X(tonumber(x_point)) +
            Y(tonumber(y_point)) +
            RZ(tonumber(r_point)),
            0,50,50
    )
    DELAY(0.2)
    DO(air_num,ON)

    repeat  until DI(air_move_num) == ON
    DO(electroc,OFF)

    DELAY(0.4)
    DO(air_num,OFF)

    repeat  until DI(air_origin_num) == ON
    ChangeTF(0)
end

function task_pick_all_fishhook(fishhook_num)

    for i, value in ipairs(DI_air_origin) do
        WAIT(DI, value, ON)
    end

    for i = 1, fishhook_num do
        task_pick_a_fishhook(tool_coordinate[i], DO_airBox[i], 
                            DO_electroc[i], DI_air_origin[i], 
                            DI_air_move[i], pick_positions_x[i], 
                            pick_positions_y[i], pick_positions_r[i])
    end

end



-- 清空数组的函数
function clear_array(arr)
    for i = #arr, 1, -1 do
        arr[i] = 0
    end
end

function clear_all_msg(num)

    message_header[num] = ""
    camera_number[num] = 0
    operating_mode[num] = 0
    action_mode[0] = 0
    reserved_variable[0] = 0

    if num == 1 then
        clear_array(pick_positions)
        clear_array(pick_positions_x)
        clear_array(pick_positions_y)
        clear_array(pick_positions_z)

    end

    if num == 2 then
        clear_array(put_positions)
        clear_array(put_positions_x)
        clear_array(put_positions_y)
        clear_array(put_positions_z)
    end
end

-- 抛料
function drop(point)   
	highZ1=RobotZ("Z")
    highZ2=ReadPoint(point,"Z")
    
    -- 气缸关
    set_io_states(DO_airBox,"OFF")
    
    --组合信号
    --DO(1,4,0)  
    
    MArchP(point,0,-highZ1,-highZ2)
    --DO(7,ON) --推进抛料区的磁铁
    
    -- 气缸开
	set_io_states(DO_airBox,"ON")
	
	--组合信号
	--DO(1,4,15) 
	
	DELAY(1)
	-- 电磁关
    set_io_states(DO_electroc,"OFF")
    
    --组合信号
	--DO(5,4,0) 

    -- 气缸关
    set_io_states(DO_airBox,"OFF")
    
    --组合信号
    --DO(1,4,0) 
    
	DELAY(1)
	--DO(7,OFF) --缩回抛料区的磁铁
end


function calibrate (point,dx,dy,dr,n) --相机标定
	PC:Send(string.format("Y,%d,1,1,0",n))
	Accur("HIGH")
    for count = 0,11 do 
        if count<9 then 
        	MArchP(point+X(dx*(count%3-1))+Y(dy*(FLOOR(count/3)-1)),0,50,50)
            DELAY(2)
        else
            MArchP(point+RZ(dr*(count%9-1)),0,50,50)
            DELAY(2)
        end
        PC:Send(string.format("Y,%d,1,0,0,%f,%f,%f",n,RobotX(), RobotY(),RobotRZ()))
        DELAY(2)
    end 
    Accur("ROUGH") 
end


up_camera_server_ip = "192.168.100.10"
up_camera_server_port = 7929

down_camera_server_ip = "192.168.100.10"
down_camera_server_port = 7930

status1 = -1
status2 = -1

function Tcp()
    -- 主机IP,端口号，间距，分隔符，cmd，睡眠时间，超时，tcp关闭。
    while status1~=0 or status2~=0 do  --0：连线成功，-1:连线失败，失败后尝试重新连接
    	PC1:Close()
    	PC2:Close()
    	DELAY(0.05)
        PC1,status1=SocketClass(up_camera_server_ip,up_camera_server_port,nil,nil,nil,nil,0.050,false) --左鱼钩字符串
        PC2,status2=SocketClass(down_camera_server_ip,down_camera_server_port,nil,nil,nil,nil,0.050,false) --右鱼钩字符串
    end

    up_received_message = nil
    down_received_message = nil
    
    up_received_message=PC1:Receive()
    down_received_message=PC2:Receive()
    
end

--[[
USER DI9	机器人去等待位
USER DI10	机器人去取料位
USER DI11	机器人去放料位
USER DI12	机器人去抛料位1
USER DI13	机器人去抛料位2
]]


function Main()

    parse_received_array( up_received_message, 1)
    parse_received_array( down_received_message, 2)

    -- 标定信号
    calibration_signal = 0
    calibration_signal = ReadModbus(0x1000, "W")

    if calibration_signal == 1 or calibration_signal == 1 then
        if calibration_signal == 1 then
            camera_calibration_num = 1
            point_name = GL_pick_name
        end

        if calibration_signal == 1 then
            camera_calibration_num = 2
            point_name = GL_flypick_name
        end 
        reset_digital_output()
        set_speed(5)

        if camera_calibration_num == 1 then
            DO( DO_airBox[1], ON)
        end
        DO( DO_electroc[1], ON)

        return_to_safe_position(GL_safe_name)
        if camera_calibration_num == 1 then
            MArchP( point_name + Z(2), 0, 50, 50)
        end
        
        PC,status=SocketClass("192.168.100.10",7929,nil,nil,nil,nil,0.050,false)

        calibrate( point_name, 30, 10, 30, camera_calibration_num)

        WriteModbus(0x1000,"W",0)
        calibration_signal = 0

    end

    -- 如果目标位置为等待位置
    if DI(go_waiting_position) == ON then
        -- 返回到安全位置
        return_to_safe_position(GL_safe_name)
        DO(to_waiting_position, ON)
    end

    -- 如果目标位置为拾取位置
    if DI(go_pick_position) == ON then
        -- 设置放置完成标记为已关闭
        DO(put_completed, OFF)
        -- 设置到等待位置标记为已关闭
        DO(to_waiting_position, OFF)
        -- 执行抓取所有鱼钩任务
        task_pick_all_fishhook(tonumber(reserved_variable[1]))
        -- 清除所有消息
        clear_all_msg(1)
        -- 设置抓取完成标记为已开启
        DO(pick_completed, ON)
        -- 返回到安全位置
        return_to_safe_position(GL_safe_name)
        DO(to_waiting_position, ON)
    end

    -- 如果目标位置为放置位置
    if DI(go_put_position) == ON then
        -- 设置抓取完成标记为已关闭
        DO(pick_completed, OFF)
        -- 设置到等待位置标记为已关闭
        DO(to_waiting_position, OFF)
        -- 执行放置所有鱼钩任务
        task_put_all_fishhook(tonumber(reserved_variable[1]))
        -- 清除所有消息
        clear_all_msg(2)
        -- 设置放置完成标记为已开启
        DO(put_completed, ON)
        return_to_safe_position(GL_safe_name)
        DO(to_waiting_position, ON)
    end

    -- 如果目标位置为投掷位置1
    if DI(go_throw_position_1) == ON then
        -- 设置抓取完成标记为已关闭
        DO(pick_completed, OFF)
        -- 设置前往等待位置标记为已关闭
        DO(to_waiting_position, OFF)
        -- 投掷
        drop()
        -- 设置投掷完成标记为已开启
        DO(throw_completed, ON)
        -- 循环直到目标位置不再为投掷位置1
        repeat until DI(go_throw_position_1) == OFF
        -- 设置投掷完成标记为已关闭
        DO(throw_completed, OFF)
    end

    -- 如果目标位置为投掷位置2
    if DI(go_throw_position_2) == ON then
        -- 设置抓取完成标记为已关闭
        DO(pick_completed, OFF)
        -- 设置前往等待位置标记为已关闭
        DO(to_waiting_position, OFF)
        -- 投掷
        drop()
        -- 设置投掷完成标记为已开启
        DO(throw_completed, ON)
        -- 循环直到目标位置不再为投掷位置2
        repeat until DI(go_throw_position_2) == OFF
        -- 设置投掷完成标记为已关闭
        DO(throw_completed, OFF)
    end

end


