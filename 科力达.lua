--IO定义--
--DI2: 放料位允许放料        DI4：下料盘放料完成
--DO1: 下料盘允许放料        DO2：放料位放料完成
--DO3-4: 气缸1-2             DO12: 气缸3
--DO11: 气缸4                DO5-6: 电磁铁1-2
--DO9-10: 电磁铁3-4
--全局变量定义--

--夹爪是否有料 1：有料，0：无料，2：多料
Grip_Full = { 0, 0, 0, 0 }

-- DO1：机器人到等待位
to_waiting_position = 1

-- DO2: 机器人1#放料完成
put_completed_1 = 2

-- DO3: 机器人2#放料完成
put_completed_2 = 3

-- DO4：机器人取料完成
pick_completed = 4

-- 气缸
DO_airBox = { 5, 6, 7, 8 }

-- 电磁
DO_electroc = { 9, 10, 11, 12 }



-- 去等待位
go_waiting_position = 1

-- DI2: 机器人去放料位
go_put_position = 2

-- DI3: 机器人去放料位
go_put_position = 3

-- DI4：机器人去取料位
go_pick_position = 4


-- 工具坐标系
tool_coordinate = { 1, 2, 3, 4 }

-- 存放接收的消息
left_hook_received_message = nil
right_hook_received_message = nil
ng_hook_received_message = nil
other_hook_received_message = nil
down_received_message = nil


-- 鱼钩个数
fishhook_count_left = 0
fishhook_count_right = 0
fishhook_count_ng = 0
fishhook_count_other = 0

-- 初始化空的坐标位置数组
pick_positions_left_num = 0
pick_positions_l = {}
pick_positions_x_l = {}
pick_positions_y_l = {}
pick_positions_r_l = {}

-- 初始化空的坐标位置数组
pick_positions_right_num = 0
pick_positions_r = {}
pick_positions_x_r = {}
pick_positions_y_r = {}
pick_positions_r_r = {}


NG_Position_num = 0
NG_Position = {}
NG_Position_x = {}
NG_Position_y = {}
NG_Position_r = {}

Other_Position_num = 0
Other_Position = {}
Other_Position_x = {}
Other_Position_y = {}
Other_Position_r = {}


put_positions_all_station = 0
put_positions = {}
put_positions_station = {}
put_positions_x = {}
put_positions_y = {}
put_positions_r = {}


function calibrate(point, dx, dy, dr, n) --相机标定
    PC6:Send(string.format("clear,%d", n))
    Accur("HIGH")
    for count = 0, 11 do
        if count < 9 then
            MArchP(point + X(dx * (count % 3 - 1)) + Y(dy * (FLOOR(count / 3) - 1)), 0, 50, 50)
            DELAY(1)
        else
            MArchP(point + RZ(dr * (count % 9 - 1)), 0, 50, 50)
            DELAY(1)
        end
        PC6:Send(string.format("%s,%d,%f,%f,%f", "calibrate", n, RobotX(), RobotY(), RobotRZ()))
        DELAY(1)
    end
    Accur("ROUGH")
end

function speed(rant) --速度,加速度，减速度百分比设定，单位%（0-100）																																																																																																							
    SpdJ(1 * rant)
    AccJ(1 * rant)
    DecJ(1 * rant)
    SpdL(20 * rant)
    AccL(250 * rant)
    DecL(250 * rant)
end

function resetdout() --输出复位
    for i = 1, 12 do
        DO(i, OFF)
    end
end

function safetyPoint(point)
    highZ1 = RobotZ("Z")
    highZ2 = ReadPoint(point, "Z")
    MArchP(point, 0, -highZ1, -highZ2)
    DO(1, ON)
end

-- IO状态设置函数
function set_io_states(io_array, desired_state)
    for i, io_value in ipairs(io_array) do
        DO(io_value, desired_state)
    end
end

function drop(point)
    -- 气缸关
    set_io_states(DO_airBox, "OFF")

    highZ1 = RobotZ("Z")
    highZ2 = ReadPoint(point, "Z")
    MArchP(point, 0, -highZ1, -highZ2)

    set_io_states(DO_electroc, "OFF")

    set_io_states(DO_airBox, "ON")
    DELAY(0.2)

    set_io_states(DO_airBox, "OFF")
end

-- 分割数组xyr 到x,y,r
function split_put_array_xyr(station_xyr, s, x, y, r)
    for i, value in ipairs(station_xyr) do
        if i % 4 == 1 then
            table.insert(s, value)
        elseif i % 4 == 2 then
            table.insert(x, value)
        elseif i % 4 == 3 then
            table.insert(y, value)
        else
            table.insert(r, value)
        end
    end
end

-- 分割数组xyr 到x,y,r
function split_pick_array_xyr(xyr, x, y, r)
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

-- 清空数组的函数
function clear_array(arr)
    if arr == nil then
        return
    end

    for i = #arr, 1, -1 do
        table.remove(arr, i)
    end
end

-- 解析接收到的数组
-- received_array: 接收到的数组
-- array_num: 数组编号，1:上相机，2：下相机

function parse_received_array(received_array, array_num)
    -- 检查数组是否为空
    if received_array == nil then
        return
    end

    if #received_array == 0 then
        return
    end

    if array_num == 1 then
        if received_array[1] == "LeftPosition" then
            clear_array(pick_positions_l)
            clear_array(pick_positions_x_l)
            clear_array(pick_positions_y_l)
            clear_array(pick_positions_r_l)

            for i = 3, #received_array do
                pick_positions_l[i - 2] = received_array[i]
            end
            fishhook_count_left = received_array[2]
            split_array_xyr(pick_positions_l, pick_positions_x_l, pick_positions_y_l, pick_positions_r_l)
        end

        if received_array[1] == "RightPosition" then
            clear_array(pick_positions_r)
            clear_array(pick_positions_x_r)
            clear_array(pick_positions_y_r)
            clear_array(pick_positions_r_r)

            for i = 3, #received_array do
                pick_positions_r[i - 2] = received_array[i]
            end

            fishhook_count_right = received_array[2]
            split_array_xyr(pick_positions_l, pick_positions_x_l, pick_positions_y_l, pick_positions_r_l)
        end

        if received_array[1] == "NGPosition" then
            clear_array(NG_Position)
            clear_array(NG_Position_x)
            clear_array(NG_Position_y)
            clear_array(NG_Position_r)

            for i = 3, #received_array do
                NG_Position[i - 2] = received_array[i]
            end

            fishhook_count_ng = received_array[2]
            split_array_xyr(NG_Position, NG_Position_x, NG_Position_y, NG_Position_r)
        end

        if received_array[1] == "OtherPosition" then
            clear_array(Other_Position)
            clear_array(Other_Position_x)
            clear_array(Other_Position_y)
            clear_array(Other_Position_r)

            for i = 3, #received_array do
                Other_Position[i - 2] = received_array[i]
            end

            fishhook_count_other = received_array[2]
            split_array_xyr(Other_Position, Other_Position_x, Other_Position_y, Other_Position_r)
        end
    end

    if array_num == 2 then
        clear_array(put_positions)
        clear_array(put_positions_station)
        clear_array(put_positions_x)
        clear_array(put_positions_y)
        clear_array(put_positions_r)

        for i = 3, #received_array do
            put_positions[i - 2] = received_array[i]
        end

        put_positions_all_station = received_array[2]
        split_put_array_xyr(put_positions, put_positions_station, put_positions_x, put_positions_y, put_positions_r)
    end
end

function task_pick_a_fishhook(i, type,
                              air_num, electroc_num,
                              fishhook_count_num, x, y, r)
    robotOnPanel = 1
    ChangeTF(i)

    local x_offset = tonumber(x)
    local y_offset = tonumber(y)
    local r_offset = tonumber(r)

    MArchP("GL_pick" + X(x_offset) + Y(y_offset) + Z(20) + RZ(r_offset), 0, 50, 50)
    print(type .. "," .. "num:" .. i .. ",x:" .. x_offset .. ",y:" .. y_offset .. ",r:" .. r_offset)

    DO(air_num, ON)
    DELAY(pickDownDelay)

    MovP("GL_pick" + X(x_offset) + Y(y_offset) + Z(0) + RZ(r_offset))

    DO(electroc_num, ON)
    DELAY(0.25)

    DO(air_num, OFF)
    DELAY(PickUp)

    ChangeTF(0)

    fishhook_count_num = fishhook_count_num - 1
    Grip_Full[i] = 1
end



function put()
    robotOnPanel = 0
    Accur("STANDARD")
    for y = 1, 2 do
        repeat until DI(2) == "ON" or DI(3) == "ON"
        if DI(2) == ON then
            highZ1 = RobotZ("Z")
            highZ2 = ReadPoint("GL_put1", "Z")
            MArchP("GL_put1" + X(tonumber(put_positions_x[1])) +
                Y(tonumber(put_positions_y[1])) +
                RZ(tonumber(put_positions_x[1])), 0, highZ1, highZ2)
            DELAY(PutReachDelay)
            DO(9, OFF)
            DELAY(PutElecDelay)


            --[[
            MovP("GL_put1"+X(tonumber(OffsetPosition[4]))+
            Y(tonumber(OffsetPosition[5])-4)+Z(0.5)+
            RZ(tonumber(OffsetPosition[6])))
            ]]
            Grip_Full[1] = 0


            DO(5, OFF)

            safetyPoint("GL_flypick")

            highZ3 = RobotZ("Z")
            highZ4 = ReadPoint("GL_put1", "Z")
            MArchP("GL_put3" + X(tonumber(put_positions_x[2])) +
                Y(tonumber(put_positions_y[2])) +
                RZ(tonumber(put_positions_r[2])), 0, highZ3, highZ4)
            DELAY(PutReachDelay)
            DO(11, OFF)
            DELAY(PutElecDelay)

            --[[
            MovP("GL_put3"+X(tonumber(OffsetPosition[12]))+
            Y(tonumber(OffsetPosition[13])-4)+Z(0.5)+
            RZ(tonumber(OffsetPosition[14])))
            ]]
            Grip_Full[3] = 0
            DO(7, OFF)
            DO(2, ON)
            safetyPoint("GL_flypick")
            DO(1, ON)
            repeat until DI(2) == OFF
            DO(2, OFF)
        end

        if DI(3) == ON then
            highZ5 = RobotZ("Z")
            highZ6 = ReadPoint("GL_put1", "Z")
            MArchP("GL_put2" + X(tonumber(OffsetPosition[8])) +
                Y(tonumber(OffsetPosition[9])) +
                RZ(tonumber(OffsetPosition[10])), 0, highZ5, highZ6)
            DELAY(PutReachDelay)
            DO(10, OFF)
            DELAY(PutElecDelay)


            --[[
            MovP("GL_put2"+X(tonumber(OffsetPosition[8]))+
            Y(tonumber(OffsetPosition[9])-4)+Z(0.5)+
            RZ(tonumber(OffsetPosition[10])))
            ]]
            Grip_Full[2] = 0

            DO(6, OFF)

            safetyPoint("GL_flypick")

            highZ7 = RobotZ("Z")
            highZ8 = ReadPoint("GL_put1", "Z")
            MArchP("GL_put4" + X(tonumber(OffsetPosition[16])) +
                Y(tonumber(OffsetPosition[17])) +
                RZ(tonumber(OffsetPosition[18])), 0, highZ7, highZ8)
            DELAY(PutReachDelay)
            DO(12, OFF)
            DELAY(PutElecDelay)

            --[[
            MovP("GL_put4"+X(tonumber(OffsetPosition[16]))+
            Y(tonumber(OffsetPosition[17])-4)+Z(0.5)+
            RZ(tonumber(OffsetPosition[18])))
            ]]
            Grip_Full[4] = 0
            DO(8, OFF)
            DO(3, ON)
            safetyPoint("GL_flypick")
            DO(1, ON)
            repeat until DI(3) == OFF
            DO(3, OFF)
        end
    end
    Accur("ROUGH")
    MovJ(3, 0)
    OffsetStation = 0
    OffsetPosition = nil
end


function sockettcp()
    -- 主机IP,端口号，间距，分隔符，cmd，睡眠时间，超时，tcp关闭。
    while status1 ~= 0 or status2 ~= 0 or status3 ~= 0 or status4 ~= 0 or status5 ~= 0 or status6 ~= 0 do --0：连线成功，-1:连线失败，失败后尝试重新连接
        PC1, status = SocketClass("192.168.101.200", 7921, nil, nil, nil, nil, 0.050, false)              --左鱼钩字符串

        PC5, status = SocketClass("192.168.101.200", 7925, nil, nil, nil, nil, 0.050, false)              --下相机纠偏鱼钩字符串
        PC6, status = SocketClass("192.168.101.200", 7925, nil, nil, nil, nil, 0.050, false)              --发送指令
    end


    -- pc1_temporary_storage 用于暂存从PC1接收的消息
    pc1_temporary_storage = nil
    -- pc5_temporary_storage 用于暂存从PC5接收的消息
    pc5_temporary_storage = nil

    -- 从PC1接收消息并存储到pc1_temporary_storage变量中
    pc1_temporary_storage = PC1:Receive()
    -- 从PC5接收消息并存储到pc5_temporary_storage变量中
    pc5_temporary_storage = PC5:Receive()

    -- 如果pc1_temporary_storage不为空
    if pc1_temporary_storage ~= nil then
        -- 如果pc1_temporary_storage的第一个元素是"LeftPosition"
        if pc1_temporary_storage[1] == "LeftPosition" then
            -- 清空left_hook_received_message变量
            left_hook_received_message = nil
            -- 将pc1_temporary_storage赋值给left_hook_received_message变量
            left_hook_received_message = pc1_temporary_storage
        end

        -- 如果pc1_temporary_storage的第一个元素是"RightPosition"
        if pc1_temporary_storage[1] == "RightPosition" then
            -- 清空right_hook_received_message变量
            right_hook_received_message = nil
            -- 将pc1_temporary_storage赋值给right_hook_received_message变量
            right_hook_received_message = pc1_temporary_storage
        end

        -- 如果pc1_temporary_storage的第一个元素是"NGPosition"
        if pc1_temporary_storage[1] == "NGPosition" then
            -- 清空ng_hook_received_message变量
            ng_hook_received_message = nil
            -- 将pc1_temporary_storage赋值给ng_hook_received_message变量
            ng_hook_received_message = pc1_temporary_storage
        end

        -- 如果pc1_temporary_storage的第一个元素是"OtherPosition"
        if pc1_temporary_storage[1] == "OtherPosition" then
            -- 清空other_hook_received_message变量
            other_hook_received_message = nil
            -- 将pc1_temporary_storage赋值给other_hook_received_message变量
            other_hook_received_message = pc1_temporary_storage
        end
    end

    -- 如果pc5_temporary_storage不为空
    if pc5_temporary_storage ~= nil then
        -- 清空down_received_message变量
        down_received_message = nil
        -- 将pc5_temporary_storage赋值给down_received_message变量
        down_received_message = pc5_temporary_storage
    end
end

function Main()
    -- sockettcp()
    if DI(1) == ON then
        safetyPoint("GL_flypick")
        DO(1, ON)
    end

    if put_positions_all_station == 0 then --总状态为0,表示四个夹爪中有缺料

        repeat until DI(4) == ON

        DO(to_waiting_position, OFF)
        DO(put_completed_1, OFF)
        DO(put_completed_2, OFF)

        if fishhook_count_ng >= 2 and Grip_Full[1] == 0 and
            Grip_Full[2] == 0 and Grip_Full[3] == 0 and
            Grip_Full[4] == 0 then --NG鱼钩个数大于1且四个电磁铁上都没鱼钩时
            for i = 1, MIN(4, fishhook_count_ng) do
                task_pick_a_fishhook(i, "NGPosition",
                    DO_airBox[i], DO_electroc[i],
                    fishhook_count_ng,
                    NG_Position_x[i],
                    NG_Position_y[i],
                    NG_Position_r[i])
            end
            pickthrow("GL_paoliao") --存在一个上相机拍照函数
            clear_array(NG_Position)
            clear_array(NG_Position_x)
            clear_array(NG_Position_y)
            clear_array(NG_Position_r)
        end

        if fishhook_count_other >= 2 and Grip_Full[1] == 0 and
            Grip_Full[2] == 0 and Grip_Full[3] == 0 and
            Grip_Full[4] == 0 then --混料鱼钩个数大于1且四个电磁铁上都没鱼钩时
            for i = 1, MIN(4, fishhook_count_other) do
                task_pick_a_fishhook(i, "OtherPosition",
                    DO_airBox[i], DO_electroc[i],
                    fishhook_count_other,
                    Other_Position_x[i],
                    Other_Position_y[i],
                    Other_Position_r[i])
            end
            pickthrow("GL_paoliao")
            clear_array(Other_Position)
            clear_array(Other_Position_x)
            clear_array(Other_Position_y)
            clear_array(Other_Position_r)
        end

        if fishhook_count_left ~= 0 then --左鱼钩个数不为零时
            for i = 1, 2 do
                if Grip_Full[i] == 0 and fishhook_count_left > 0 then
                    task_pick_a_fishhook(i, "LeftPosition",
                        DO_airBox[i], DO_electroc[i],
                        fishhook_count_left,
                        pick_positions_x_l[i],
                        pick_positions_y_l[i],
                        pick_positions_r_l[i])
                end
            end
            clear_array(pick_positions_l)
            clear_array(pick_positions_x_l)
            clear_array(pick_positions_y_l)
            clear_array(pick_positions_r_l)
        end

        if fishhook_count_left ~= 0 then --右鱼钩个数不为零时
            for i = 3, 4 do
                if Grip_Full[i] == 0 and fishhook_count_left > 0 then
                    task_pick_a_fishhook(i, "RightPosition",
                        DO_airBox[i], DO_electroc[i],
                        fishhook_count_left,
                        pick_positions_x_r[i-2],
                        pick_positions_y_r[i-2],
                        pick_positions_r_r[i-2])
                end
            end
            clear_array(pick_positions_r)
            clear_array(pick_positions_x_r)
            clear_array(pick_positions_y_r)
            clear_array(pick_positions_r_r)
        end

        if Grip_Full[1] >= 1 and --四个夹爪均有料
            Grip_Full[2] >= 1 and Grip_Full[3] >= 1 and
            Grip_Full[4] >= 1 then

            Accur("STANDARD")
            MArchP("GL_flypick", 0, 50, 50)
            DO(to_waiting_position, ON)
            DELAY(0.7)

            robotOnPanel = 0
            put_positions_all_station = -1

            PC6:Send(string.format("putshot")) --下相机拍照
            Accur("ROUGH")
        else
            MArchP("GL_flypick", 0, 50, 50)
            DO(1, ON)
            robotOnPanel = 0

            if baitcamerashot == 0 then
                upcamerashot()
                print("elseshot")
            end

            baitcamerashot = 0
        end
    end

    print(put_positions_all_station)

    if put_positions_all_station == 1 then --四个夹爪满料
        DO(pick_completed, ON)
        repeat until DI(go_pick_position) == OFF
        DO(pick_completed, OFF)
        Grip_Full[1] = 0
        Grip_Full[2] = 0
        Grip_Full[3] = 0
        Grip_Full[4] = 0

        robotOnPanel = 0
        fishhook_count_left = 0
        fishhook_count_right = 0

        upcamerashot()
        print("putshot")
        baitcamerashot = 1
        put()
    end

    if put_positions_all_station == 2 then --有夹爪多吸料
        putthrow()
    end
end
