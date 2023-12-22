--项目：
--制定人：郭耀雄
--日期：2023/10/17
--修订人：***
--修订日期：****/**/**
--修订次数：**次
--备注：

--点位定义--
--GL_pick: 取料位            GL_flypick：拍照位
--GL_put1: 放料位2           GL_put2: 放料位4
--GL_put3: 放料位1           GL_put4: 放料位3
--GL_paoliao: NG抛料位

--IO定义--
--DI2: 放料位允许放料        DI4：下料盘放料完成
--DO1: 下料盘允许放料        DO2：放料位放料完成
--DO3-4: 气缸1-2             DO12: 气缸3
--DO11: 气缸4                DO5-6: 电磁铁1-2
--DO9-10: 电磁铁3-4
--全局变量定义--
Grip_Full = { 4 }
Grip_Full[1] = 0
Grip_Full[2] = 0
Grip_Full[3] = 0
Grip_Full[4] = 0

Grip_Full_Only = { 4 }
Grip_Full_Only[1] = 0
Grip_Full_Only[2] = 0
Grip_Full_Only[3] = 0
Grip_Full_Only[4] = 0

LeftPosition = nil
LeftCountAll = 0
LeftCount = 0

RightPosition = nil
RightCountAll = 0
RightCount = 0

NGPosition = nil
NGCountAll = 0
NGCount = 0

OtherPosition = nil
OtherCountAll = 0
OtherCount = 0

OffsetPosition = nil
OffsetStation = 0

pickDownDelay = 0.3 --取料气缸下降到位延时
PickUp = 0.1       --取料上升延时
PutReachDelay = 0.02 --放料机器人到位延时
PutDownDelay = 0.15 --放料气缸到位延时
PutElecDelay = 0.5 --放料电磁铁断磁延时
PutUpDelay = 0.1   --放料气缸抬起延时

robotOnPanel = 0


MArchL_top_pick = ReadPoint("GL_pick", "Z") + 20
MArchL_top_put = ReadPoint("GL_put11", "Z") + 20
--------------
--封装功能块--
--------------

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
    MArchL(point, 0, -highZ1, -highZ2)
    DO(1, ON)
end

function drop(point) --
    DO(5, OFF)
    DO(6, OFF)
    DO(7, OFF)
    DO(8, OFF)
    highZ1 = RobotZ("Z")
    highZ2 = ReadPoint(point, "Z")
    MArchP(point, 0, -highZ1, -highZ2)
    DO(9, OFF)
    DO(10, OFF)
    DO(11, OFF)
    DO(12, OFF)
    DO(5, ON)
    DELAY(1)
    DO(6, ON)
    DELAY(1)
    DO(7, ON)
    DELAY(1)
    DO(8, ON)
    DELAY(1)
    DO(5, OFF)
    DELAY(0.2)
    DO(6, OFF)
    DELAY(0.2)
    DO(7, OFF)
    DELAY(0.2)
    DO(8, OFF)
    DELAY(0.2)
    highZ1 = RobotZ("Z")
    highZ2 = ReadPoint("GL_flypick", "Z")
    MArchP("GL_flypick", 0, -highZ1, -highZ2)
end

baitcamerashot = 0
function sockettcp()
    -- 主机IP,端口号，间距，分隔符，cmd，睡眠时间，超时，tcp关闭。
    while status1 ~= 0 or status2 ~= 0 or status3 ~= 0 or status4 ~= 0 or status5 ~= 0 or status6 ~= 0 do --0：连线成功，-1:连线失败，失败后尝试重新连接
        PC1, status = SocketClass("192.168.100.10", 7921, nil, nil, nil, nil, 0.050, false)    --左鱼钩字符串
        PC2, status = SocketClass("192.168.100.10", 7922, nil, nil, nil, nil, 0.050, false)    --右鱼钩字符串
        PC3, status = SocketClass("192.168.100.10", 7923, nil, nil, nil, nil, 0.050, false)    --NG鱼钩字符串
        PC4, status = SocketClass("192.168.100.10", 7924, nil, nil, nil, nil, 0.050, false)    --混料鱼钩字符串
        PC5, status = SocketClass("192.168.100.10", 7925, nil, nil, nil, nil, 0.050, false)    --下相机纠偏鱼钩字符串
        PC6, status = SocketClass("192.168.100.10", 7920, nil, nil, nil, nil, 0.050, false)    --发送指令
    end
    LeftPositionTCP = nil
    RightPositionTCP = nil
    NGPositionTCP = nil
    OtherPositionTCP = nil
    OffsetPositionTCP = nil
    LeftPositionTCP = PC1:Receive()
    --RightPositionTCP=PC2:Receive()
    --NGPositionTCP=PC3:Receive()
    --OtherPositionTCP=PC4:Receive()
    OffsetPositionTCP = PC5:Receive()
    if LeftPositionTCP ~= nil then
        if LeftPositionTCP[1] == "LeftPosition" then
            LeftCountAll = tonumber(LeftPositionTCP[2])
            LeftCount = LeftCountAll
            LeftPosition = LeftPositionTCP
            --LeftPositionTCP=nil
            --OffsetStation=0
            robotOnPanel = 1
        end
        if LeftPositionTCP[1] == "RightPosition" then
            RightCountAll = tonumber(LeftPositionTCP[2])
            RightCount = RightCountAll
            RightPosition = LeftPositionTCP

            RightPositionTCP = nil
            OffsetStation = 0
            robotOnPanel = 1
        end
        if LeftPositionTCP[1] == "NGPosition" then
            NGCountAll = tonumber(LeftPositionTCP[2])
            NGCount = NGCountAll
            NGPosition = LeftPositionTCP
            NGPositionTCP = nil
            --OffsetStation=0
            robotOnPanel = 1
        end
        if LeftPositionTCP[1] == "OtherPosition" then
            OtherCountAll = tonumber(LeftPositionTCP[2])
            OtherCount = OtherCountAll
            OtherPosition = LeftPositionTCP
            OtherPositionTCP = nil
            --OffsetStation=0
            robotOnPanel = 1
        end
        LeftPositionTCP = nil
    end
    --[[
             if OffsetPositionTCP~=nil then
            OffsetStation=tonumber(OffsetPositionTCP[2])
            Grip_Full[1]=tonumber(OffsetPositionTCP[3])
            Grip_Full[2]=tonumber(OffsetPositionTCP[7])
            Grip_Full[3]=tonumber(OffsetPositionTCP[11])
            Grip_Full[4]=tonumber(OffsetPositionTCP[15])
            if tonumber(OffsetPositionTCP[3])==2 then
            	Grip_Full[1]=0
            end
            if tonumber(OffsetPositionTCP[7])==2 then
            	Grip_Full[2]=0
            end
            if tonumber(OffsetPositionTCP[11])==2 then
            	Grip_Full[3]=0
            end
            if tonumber(OffsetPositionTCP[15])==2 then
            	Grip_Full[4]=0
            end
            OffsetPosition=OffsetPositionTCP
            OffsetPositionTCP=nil

       end	
       ]]


    coroutine.yield()
end

--取料函数，type-取料坐标数组类型，i--夹爪序号
function pick(type, i)
    robotOnPanel = 1
    --定义气缸电磁铁序号变量，修改工具坐标系
    airBox = 0
    electroc = 0
    ChangeTF(i)
    --为气缸电磁铁序号赋值
    if i == 1 then
        airBox = 5
        electroc = 9
    elseif i == 2 then
        airBox = 6
        electroc = 10
    elseif i == 3 then
        airBox = 7
        electroc = 11
    elseif i == 4 then
        airBox = 8
        electroc = 12
    end

    if type == "LeftPosition" and LeftPosition == nil then
        upcamerashot()
    end

    if type == "RightPosition" and RightPosition == nil then
        upcamerashot()
    end

    if type == "NGPosition" and NGPosition == nil then
        upcamerashot()
    end

    if type == "OtherPosition" and OtherPosition == nil then
        upcamerashot()
    end

    sockettcp()

    --取左OK鱼钩
    if type == "LeftPosition" and LeftPosition ~= nil then
        x_offset = tonumber(LeftPosition[(LeftCountAll - LeftCount) * 3 + 3])
        y_offset = tonumber(LeftPosition[(LeftCountAll - LeftCount) * 3 + 4])
        r_offset = tonumber(LeftPosition[(LeftCountAll - LeftCount) * 3 + 5])
        MArchL("GL_pick" + X(x_offset) + Y(y_offset) + Z(20) + RZ(r_offset), MArchL_top_pick, 50, 50)
        DO(airBox, ON)
        DELAY(pickDownDelay)

        print("LeftPosition," .. "num:" .. i .. ",x:" .. x_offset .. ",y:" .. y_offset .. ",r:" .. r_offset)

        MovP("GL_pick" + X(x_offset) + Y(y_offset) + Z(0) + RZ(r_offset))
        DO(electroc, ON)
        DELAY(0.25)
        DO(airBox, OFF)
        DELAY(PickUp)
        ChangeTF(0)
        LeftCount = LeftCount - 1
        Grip_Full[i] = 1
        Grip_Full_Only[i] = 1
    end
    --取右OK鱼钩
    if type == "RightPosition" and RightPosition ~= nil then
        if RightPosition == nil then
            upcamerashot()
        end
        x_offset = tonumber(RightPosition[(RightCountAll - RightCount) * 3 + 3])
        y_offset = tonumber(RightPosition[(RightCountAll - RightCount) * 3 + 4])
        r_offset = tonumber(RightPosition[(RightCountAll - RightCount) * 3 + 5])
        MArchL("GL_pick" + X(x_offset) + Y(y_offset) + Z(20) + RZ(r_offset), MArchL_top_pick, 50, 50)

        print("RightPosition," .. "num:" .. i .. ",x:" .. x_offset .. ",y:" .. y_offset .. ",r:" .. r_offset)

        DO(airBox, ON)
        DELAY(pickDownDelay)
        MovP("GL_pick" + X(x_offset) + Y(y_offset) + Z(0) + RZ(r_offset))
        DO(electroc, ON)
        DELAY(0.25)
        DO(airBox, OFF)
        DELAY(PickUp)
        ChangeTF(0)
        RightCount = RightCount - 1
        Grip_Full[i] = 1
        Grip_Full_Only[i] = 1
    end
    --取NG鱼钩
    if type == "NGPosition" and NGPosition ~= nil then
        x_offset = tonumber(NGPosition[(NGCountAll - NGCount) * 3 + 3])
        y_offset = tonumber(NGPosition[(NGCountAll - NGCount) * 3 + 4])
        r_offset = tonumber(NGPosition[(NGCountAll - NGCount) * 3 + 5])
        MArchL("GL_pick" + X(x_offset) + Y(y_offset) + RZ(r_offset), 0, 50, 50)

        print("num:" .. i .. ",x:" .. x_offset .. ",y:" .. y_offset .. ",r:" .. r_offset)

        DO(airBox, ON)
        DELAY(pickDownDelay)
        DO(electroc, ON)
        DELAY(pickDownDelay)
        DO(airBox, OFF)
        DELAY(PickUp)
        ChangeTF(0)
        NGCount = NGCount - 1
        Grip_Full[i] = 1
        Grip_Full_Only[i] = 1
    end
    --取Other鱼钩
    if type == "OtherPosition" and OtherPosition ~= nil then
        x_offset = tonumber(OtherPosition[(OtherCountAll - OtherCount) * 3 + 3])
        y_offset = tonumber(OtherPosition[(OtherCountAll - OtherCount) * 3 + 4])
        r_offset = tonumber(OtherPosition[(OtherCountAll - OtherCount) * 3 + 5])
        MArchL("GL_pick" + X(x_offset) + Y(y_offset) + RZ(r_offset), 0, 50, 50)

        print("num:" .. i .. ",x:" .. x_offset .. ",y:" .. y_offset .. ",r:" .. r_offset)

        DO(airBox, ON)
        DELAY(pickDownDelay)
        DO(electroc, ON)
        DO(airBox, OFF)
        DELAY(PickUp)
        ChangeTF(0)
        OtherCount = OtherCount - 1
        Grip_Full[i] = 1
        Grip_Full_Only[i] = 1
    end
    airBox = 0
    electroc = 0
end

function put()
    robotOnPanel = 0
    Accur("STANDARD")
    for y = 1, 2 do
        repeat until DI(2) == "ON" or DI(3) == "ON" or DI(4) == "ON"
        if DI(2) == ON then
            highZ1 = RobotZ("Z")
            highZ2 = ReadPoint("GL_put11", "Z")

            MArchL("GL_put11" + X(tonumber(OffsetPosition[4])) +
                Y(tonumber(OffsetPosition[5])) +
                Z(0) +
                RZ(tonumber(OffsetPosition[6])), 0, highZ1, highZ2)

            --[[
            MovP("GL_put11"+X(tonumber(OffsetPosition[4]) + 3)+
            Y(tonumber(OffsetPosition[5]))+Z(0)+
            RZ(tonumber(OffsetPosition[6])))
            ]]


            DELAY(PutReachDelay)
            DO(9, OFF)
            DELAY(PutElecDelay)

            if put_translate_enable == 1 then
                MovP("GL_put11" + X(tonumber(OffsetPosition[4]) + 3) +
                    Y(tonumber(OffsetPosition[5])) + Z(0.5) +
                    RZ(tonumber(OffsetPosition[6])))
            end

            Grip_Full[1] = 0
            Grip_Full_Only[1] = 0
            DO(5, OFF)
            --safetyPoint("GL_flypick")

            highZ3 = RobotZ("Z")
            highZ4 = ReadPoint("GL_put23", "Z")

            MArchL("GL_put23" + X(tonumber(OffsetPosition[12])) +
                Y(tonumber(OffsetPosition[13])) +
                Z(0) +
                RZ(tonumber(OffsetPosition[14])), MArchL_top_put, highZ3, highZ4)

            --[[
            MovP("GL_put23"+X(tonumber(OffsetPosition[12]) + 3)+
            Y(tonumber(OffsetPosition[13]))+Z(0)+
            RZ(tonumber(OffsetPosition[14])))
            ]]


            DELAY(PutReachDelay)
            print("x:" .. RobotX() .. ",y:" .. RobotY() .. ",R:" .. RobotRZ())
            DO(11, OFF)
            DELAY(PutElecDelay)

            if put_translate_enable == 1 then
                MovP("GL_put23" + X(tonumber(OffsetPosition[12]) + 3) +
                    Y(tonumber(OffsetPosition[13])) + Z(0.5) +
                    RZ(tonumber(OffsetPosition[14])))
            end

            Grip_Full[3] = 0
            Grip_Full_Only[3] = 0
            DO(7, OFF)
            safetyPoint("GL_flypick")
            DO(2, ON)
            DO(1, ON)
            repeat until DI(2) == OFF
            DO(2, OFF)
        elseif DI(3) == ON then
            highZ5 = RobotZ("Z")
            highZ6 = ReadPoint("GL_put32", "Z")

            MArchL("GL_put32" + X(tonumber(OffsetPosition[8])) +
                Y(tonumber(OffsetPosition[9])) +
                Z(0) +
                RZ(tonumber(OffsetPosition[10])), 0, highZ5, highZ6)

            --[[
            MovP("GL_put32"+X(tonumber(OffsetPosition[8]))+
            Y(tonumber(OffsetPosition[9]))+Z(0)+
            RZ(tonumber(OffsetPosition[10])))
            ]]

            DELAY(PutReachDelay)
            DO(10, OFF)
            DELAY(PutElecDelay)

            if put_translate_enable == 1 then
                MovP("GL_put32" + X(tonumber(OffsetPosition[8]) + 3) +
                    Y(tonumber(OffsetPosition[9])) + Z(0.5) +
                    RZ(tonumber(OffsetPosition[10])))
            end

            Grip_Full[2] = 0
            Grip_Full_Only[2] = 0
            DO(6, OFF)
            --safetyPoint("GL_flypick")
            highZ7 = RobotZ("Z")
            highZ8 = ReadPoint("GL_put44", "Z")
            MArchL("GL_put44" + X(tonumber(OffsetPosition[16])) +
                Y(tonumber(OffsetPosition[17])) +
                Z(0) +
                RZ(tonumber(OffsetPosition[18])), MArchL_top_put, highZ7, highZ8)

            --[[
            MovP("GL_put44"+X(tonumber(OffsetPosition[16]))+
            Y(tonumber(OffsetPosition[17]))+Z(0)+
            RZ(tonumber(OffsetPosition[18])))
            ]]

            DELAY(PutReachDelay)
            DO(12, OFF)
            DELAY(PutElecDelay)

            if put_translate_enable == 1 then
                MovP("GL_put44" + X(tonumber(OffsetPosition[16]) + 3) +
                    Y(tonumber(OffsetPosition[17])) + Z(0.5) +
                    RZ(tonumber(OffsetPosition[18])))
            end

            Grip_Full[4] = 0
            Grip_Full_Only[4] = 0
            DO(8, OFF)
            safetyPoint("GL_flypick")
            DO(3, ON)
            DO(1, ON)
            repeat until DI(3) == OFF
            DO(3, OFF)
        elseif DI(4) == ON then
            print("shield a station")
        end
    end
    Accur("ROUGH")
    MovJ(3, 0)
    OffsetStation = 0
    OffsetPosition = nil
end

function pickthrow(point)
    robotOnPanel = 0
    DO(5, ON)
    DELAY(0.2)
    DO(6, ON)
    DELAY(0.2)
    DO(7, ON) --气缸3
    DELAY(0.2)
    DO(8, ON) --气缸4
    DELAY(0.2)
    MArchL(point, 0, 30, 30)
    Grip_Full[1] = 0
    Grip_Full[2] = 0
    Grip_Full[3] = 0
    Grip_Full[4] = 0
    Grip_Full_Only[1] = 0
    Grip_Full_Only[2] = 0
    Grip_Full_Only[3] = 0
    Grip_Full_Only[4] = 0
    upcamerashot()
    DO(9, OFF)
    DO(10, OFF)
    DO(11, OFF)
    DO(12, OFF)
    DELAY(1)
    DO(5, OFF)
    DO(6, OFF)
    DO(7, OFF)
    DO(8, OFF)
    DELAY(1)
    OffsetStation = 0
    --robotOnPanel=0
    --upcamerashot()
    OffsetPosition = nil
end

function putthrow()
    robotOnPanel = 0
    --DELAY(1)
    MArchL("GL_paoliao", 0, 30, 30)
    for i = 1, 4 do
        --定义气缸电磁铁序号变量，修改工具坐标系
        airBox = 0
        electroc = 0
        if i == 1 then
            airBox = 5
            electroc = 9
        elseif i == 2 then
            airBox = 6
            electroc = 10
        elseif i == 3 then
            airBox = 7
            electroc = 11
        elseif i == 4 then
            airBox = 8
            electroc = 12
        end
        --[[
		   if tonumber(OffsetPosition[4*(i-1)+3]) == 2 or
		   tonumber(OffsetPosition[4*(i-1)+3]) == 0 then
		   ]]
        if (Grip_Full[i] ~= 1 and
                Grip_Full_Only[i] == 1) then
            DO(electroc, OFF)
            DO(airBox, ON)
            DELAY(0.5)
            DO(airBox, OFF)
            DELAY(0.6)
            Grip_Full[i] = 0
            Grip_Full_Only[i] = 0
        end
        --[[
				
        if OffsetPosition ~= nil then
			if tonumber(OffsetPosition[4*(i-1)+3]) ==  2 then
                DO(electroc,OFF)
                DO(airBox,ON)
                DELAY(0.5)
                DO(airBox,OFF)
                DELAY(0.6)
                Grip_Full[i]=0
                Grip_Full_Only[i] = 0
            end
		end
		
		]]
    end
    DELAY(1)
    OffsetStation = 0
    OffsetPosition = nil
end

function upcamerashot(flag)
    --LeftCountNeed=(2-Grip_Full[1]-Grip_Full[2])-LeftCount
    --RightCountNeed=(2-Grip_Full[3]-Grip_Full[4])-RightCount
    LeftCountNeed = 0
    RightCountNeed = 0
    if Grip_Full[1] ~= 1 then
        LeftCountNeed = LeftCountNeed + 1
    end

    if Grip_Full[2] ~= 1 then
        LeftCountNeed = LeftCountNeed + 1
    end

    if Grip_Full[3] ~= 1 then
        RightCountNeed = RightCountNeed + 1
    end

    if Grip_Full[4] ~= 1 then
        RightCountNeed = RightCountNeed + 1
    end

    --[[
    LeftCountNeed = LeftCountNeed - LeftCount
    RightCountNeed = RightCountNeed - RightCount
    ]]

    LeftCountNeed = LeftCountNeed
    RightCountNeed = RightCountNeed

    if flag == "PUT" then
        LeftCountNeed = 2
        RightCountNeed = 2
    end


    print("LeftCountNeed:" .. "," .. LeftCountNeed .. Grip_Full[1] .. "," .. Grip_Full[2] .. "," .. LeftCount)
    print("RightCountNeed:" .. "," .. RightCountNeed .. Grip_Full[3] .. "," .. Grip_Full[4] .. "," .. RightCount)

    if (LeftCountNeed > 0 or RightCountNeed > 0) and robotOnPanel == 0 then
        LeftPosition = nil
        RightPosition = nil
        NGPosition = nil
        OtherPosition = nil
        LeftCount = 0
        RightCount = 0
        NGCount = 0
        OtherCount = 0
        --LeftCountNeed=(2-Grip_Full[1]-Grip_Full[2])-LeftCount
        --RightCountNeed=(2-Grip_Full[3]-Grip_Full[4])-RightCount
        OffsetStation = -1
        PC6:Send(string.format("pickshot,%d,%d", LeftCountNeed, RightCountNeed)) --上相机拍照
    end
end

function Main()
    -- sockettcp()
    if DI(1) == ON then
        safetyPoint("GL_flypick")
        DO(1, ON)
    end

    if OffsetStation ~= nil then
        print("first,OffsetStation:" .. OffsetStation)
    end

    if OffsetStation == 0 then   --总状态为0,表示四个夹爪中有缺料
        print("OffsetStation:" .. OffsetStation .. ":缺料")


        for i = 1, 4 do
            if Grip_Full[i] ~= 1 and Grip_Full_Only[i] == 1 then
                print("putthrow")
                putthrow()
            end
        end

        repeat until DI(4) == ON
        DO(1, OFF)
        DO(2, OFF)
        DO(3, OFF)
        if NGCount >= 2 and Grip_Full[1] == 0 and
            Grip_Full[2] == 0 and Grip_Full[3] == 0 and
            Grip_Full[4] == 0 then   --NG鱼钩个数大于1且四个电磁铁上都没鱼钩时
            for i = 1, MIN(4, NGCount) do
                pick("NGPosition", i)
            end
            pickthrow("GL_paoliao")     --存在一个上相机拍照函数
        end

        if OtherCount >= 2 and Grip_Full[1] == 0 and
            Grip_Full[2] == 0 and Grip_Full[3] == 0 and
            Grip_Full[4] == 0 then --混料鱼钩个数大于1且四个电磁铁上都没鱼钩时
            for i = 1, MIN(4, OtherCount) do
                pick("OtherPosition", i)
            end
            pickthrow("GL_paoliao")
        end

        if LeftCount ~= 0 then   --左鱼钩个数不为零时
            for i = 1, 2 do
                if Grip_Full[i] == 0 and LeftCount > 0 then
                    pick("LeftPosition", i)
                end
            end
            LeftPosition = nil
        end

        if RightCount ~= 0 then   --右鱼钩个数不为零时
            for i = 3, 4 do
                if Grip_Full[i] == 0 and RightCount > 0 then
                    pick("RightPosition", i)
                end
            end
            RightPosition = nil
        end
        print("A:" .. Grip_Full[1] .. "B:" .. Grip_Full[2] .. "C:" .. Grip_Full[3] .. "D:" .. Grip_Full[4])
        if Grip_Full[1] >= 1 and   --四个夹爪均有料
            Grip_Full[2] >= 1 and Grip_Full[3] >= 1 and
            Grip_Full[4] >= 1 then
            Accur("STANDARD")
            MArchL("GL_flypick", 0, 50, 50)
            print("Grip_Full_pull go GL_flypick")
            DO(1, ON)
            DELAY(0.7)
            robotOnPanel = 0
            OffsetStation = -1
            PC6:Send(string.format("putshot"))     --下相机拍照
            print("OffsetStation:" .. OffsetStation .. ":下相机拍照")
            upcamerashot()
            Accur("ROUGH")
        else
            MArchL("GL_flypick", 0, 50, 50)
            print("OffsetStation:" .. OffsetStation .. ",else:" .. baitcamerashot)
            DO(1, ON)
            robotOnPanel = 0
            --if baitcamerashot==0 then
            upcamerashot()
            print("elseshot")
            --end
            baitcamerashot = 0
        end
    end

    if OffsetStation ~= nil then
        print("OffsetStation:" .. OffsetStation)
    end

    if OffsetStation == 1 then   --四个夹爪满料
        DO(4, ON)
        repeat until DI(4) == OFF
        DO(4, OFF)
        --[[
        	Grip_Full[1]=0
        	Grip_Full[2]=0
        	Grip_Full[3]=0
        	Grip_Full[4]=0
        	]]
        robotOnPanel = 0
        LeftCount = 0
        RightCount = 0
        upcamerashot("PUT")
        print("putshot")
        baitcamerashot = 1
        put()
        all_num = all_num + 1
        print("all_num:" .. all_num)
    end

    if OffsetStation == 2 then     --有夹爪多吸料
        print("putthrow")
        putthrow()
    end
    coroutine.yield()
end

all_num = 0

RobotServoOff()
speed_value = 2
speed(speed_value) --速度,加速度，减速度百分比设定，单位%（0-100）
--WriteModbus(0x3000,"W",speed_value)
--SetPayload(1.0,0,0,0,0,0,0.005)--设置负载和惯量

--PassMode("TIME1")--插段（时间插段或者位置插段，动作会更柔顺）
--PassMode("DEC")
--SetOverlapTime(100)--设定pass速度叠合模式 100为不启用pass
--getFunction("JerkL")(0)--加加速度，可以使加速度更快
--RABDROBOT_SetMinAMF(20)--运动模式，範圍一般在20~100，值越小速度越快，但是幾台越容易晃动
--RABDROBOT_SetAMF(10) --运动模式，範圍一般在10~40，值越小速度越快，但是幾台越容易晃动
RobotServoOn()
Accur("ROUGH")
--HIGH:設定到位精度最高，其整定時間較長
--STANDARD:設定到位精度標準，其到位的精度僅次於HIGH，整定時間較短於HIGH
--MEDIUM:到位精度一般，其到位的精度僅次於STANDARD，整定時間較短於STANDARD
--ROUGH:到位精度較低，在整定時間較STANDARD短以及精準度較MAXROUGH高
--MAXROUGH:到位精度最低，其到達目標點位的整定時間是最短的，當動作較大且在運動
--過程中較不會受到外在干涉的情況下，可以將手臂的到位精度調整到最低，以提升動作效能
--speed(40)--速度,加速度，减速度百分比设定，单位%（0-100）
WriteModbus(0x1000, "W", 0)
DELAY(1)
resetdout()
DELAY(1)
safetyPoint("GL_flypick")
drop("GL_paoliao")
LeftPosition = nil
RightPosition = nil
NGPosition = nil
OtherPosition = nil
LeftCountAll = 0
RightCountAll = 0
NGCountAll = 0
OtherCountAll = 0
LeftCount = 0
RightCount = 0
NGCount = 0
OtherCount = 0

status1 = -1
status2 = -1
status3 = -1
status4 = -1
status5 = -1
status6 = -1
while status1 ~= 0 or status2 ~= 0 or status3 ~= 0 or status4 ~= 0 or status5 ~= 0 or status6 ~= 0 do --0：连线成功，-1:连线失败，失败后尝试重新连接
    PC1, status1 = SocketClass("192.168.100.10", 7921, nil, nil, nil, nil, 0.050, false)  --左鱼钩字符串
    PC2, status2 = SocketClass("192.168.100.10", 7922, nil, nil, nil, nil, 0.050, false)  --右鱼钩字符串
    PC3, status3 = SocketClass("192.168.100.10", 7923, nil, nil, nil, nil, 0.050, false)  --NG鱼钩字符串
    PC4, status4 = SocketClass("192.168.100.10", 7924, nil, nil, nil, nil, 0.050, false)  --混料鱼钩字符串
    PC5, status5 = SocketClass("192.168.100.10", 7925, nil, nil, nil, nil, 0.050, false)  --下相机纠偏鱼钩字符串
    PC6, status6 = SocketClass("192.168.100.10", 7920, nil, nil, nil, nil, 0.050, false)  --链接相机
    print(status1 .. status2 .. status3 .. status4 .. status5 .. status6)
end

upcamerashot()

put_translate_enable = 1

while true do
    --if ReadModbus(0x1000,"W")==1 then--生产鱼钩
    speed_value = ReadModbus(0x3000, "W")
    speed(speed_value)
    if OffsetPositionTCP ~= nil then
        OffsetStation = tonumber(OffsetPositionTCP[2])
        Grip_Full[1] = tonumber(OffsetPositionTCP[3])
        Grip_Full[2] = tonumber(OffsetPositionTCP[7])
        Grip_Full[3] = tonumber(OffsetPositionTCP[11])
        Grip_Full[4] = tonumber(OffsetPositionTCP[15])
        if tonumber(OffsetPositionTCP[3]) == 2 then
            Grip_Full[1] = 0
        end
        if tonumber(OffsetPositionTCP[7]) == 2 then
            Grip_Full[2] = 0
        end
        if tonumber(OffsetPositionTCP[11]) == 2 then
            Grip_Full[3] = 0
        end
        if tonumber(OffsetPositionTCP[15]) == 2 then
            Grip_Full[4] = 0
        end
        OffsetPosition = OffsetPositionTCP
        OffsetPositionTCP = nil
    end
    MultiTask(Main, sockettcp)
    --end

    if ReadModbus(0x1001, "W") == 1 then --上相机标定
        WriteModbus(0x1001, "W", 0)
        DO(5, OFF)
        DO(6, OFF)
        DO(7, OFF)
        DO(8, OFF)
        DELAY(1)
        speed(5)
        MArchP("GL_pick" + Z(20), 0, 50, 50)
        DO(6, ON)
        MArchP("GL_pick" + Z(2), 0, 50, 50)
        DELAY(2)
        PC6, status = SocketClass("192.168.100.10", 7920, nil, nil, nil, nil, 0.050, false)
        calibrate("GL_pick", 10, 10, 15, 1)
    end

    if ReadModbus(0x1002, "W") == 1 then --下相机标定
        WriteModbus(0x1002, "W", 0)
        DO(5, OFF)
        DO(6, OFF)
        DO(7, OFF)
        DO(8, OFF)
        DELAY(1)
        speed(5)
        DO(9, ON)
        DO(10, ON)
        DELAY(2)
        PC6, status = SocketClass("192.168.100.10", 7920, nil, nil, nil, nil, 0.050, false)
        calibrate("GL_flypick", 15, 15, 45, 2)
    end

    collectgarbage()
end
