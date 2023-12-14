--IO定义--
--DI2: 放料位允许放料        DI4：下料盘放料完成
--DO1: 下料盘允许放料        DO2：放料位放料完成
--DO3-4: 气缸1-2             DO12: 气缸3
--DO11: 气缸4                DO5-6: 电磁铁1-2
--DO9-10: 电磁铁3-4       
--全局变量定义--

--夹爪是否有料
Grip_Full = {0, 0, 0, 0}

-- 左鱼钩点位，左鱼钩总数，左鱼钩数
LeftPosition = nil
LeftCountAll = 0
LeftCount = 0

-- 右鱼钩点位，右鱼钩总数，右鱼钩数
RightPosition = nil
RightCountAll = 0
RightCount = 0

-- NG钩点位，NG钩总数，NG钩数
NGPosition = nil
NGCountAll = 0
NGCount = 0

-- 其他钩点位，其他钩总数，其他钩数
OtherPosition = nil
OtherCountAll = 0
OtherCount = 0

-- 偏移点位，偏移状态
OffsetPosition = nil
OffsetStation = 0

-- 气缸
DO_airBox = {5,6,7,8}

-- 电磁  
DO_electroc = {9,10,11,12}

-- DO1：机器人到等待位
to_waiting_position = 1

-- DO2: 机器人1#放料完成
put_completed = 2

-- DO3: 机器人2#放料完成
put_completed = 3

-- DO4：机器人取料完成
pick_completed = 4

-- 去等待位
go_waiting_position = 1

-- DI2: 机器人去放料位
go_put_position = 2

-- DI3: 机器人去放料位
go_put_position = 3

-- DI4：机器人去取料位
go_pick_position = 4


-- 工具坐标系
tool_coordinate = {1,2,3,4}

-- 初始化空的坐标位置数组
pick_positions_l = {}
pick_positions_x_l = {}
pick_positions_y_l = {}
pick_positions_r_l = {}

-- 初始化空的坐标位置数组
pick_positions_r = {}
pick_positions_x_r = {}
pick_positions_y_r = {}
pick_positions_r_r = {}

put_positions = {}
put_positions_station = {}
put_positions_x = {}
put_positions_y = {}
put_positions_r = {}


function calibrate (point,dx,dy,dr,n) --相机标定
	PC6:Send(string.format("clear,%d",n))
	Accur("HIGH")
    for count = 0,11 do 
        if count<9 then 
        	MArchP(point+X(dx*(count%3-1))+Y(dy*(FLOOR(count/3)-1)),0,50,50)
            DELAY(1)
        else
            MArchP(point+RZ(dr*(count%9-1)),0,50,50)
            DELAY(1)
        end
        PC6:Send(string.format("%s,%d,%f,%f,%f","calibrate",n,RobotX(), RobotY(),RobotRZ()))
        DELAY(1)
    end 
    Accur("ROUGH") 
end



function speed(rant) --速度,加速度，减速度百分比设定，单位%（0-100）																																																																																																							
    SpdJ(1*rant)
    AccJ(1*rant)
    DecJ(1*rant)
    SpdL(20*rant)
    AccL(250*rant)
    DecL(250*rant)
end


function resetdout()  --输出复位
    for i=1,12 do
        DO(i,OFF)
    end
end

function safetyPoint(point)
	highZ1=RobotZ("Z")
    highZ2=ReadPoint(point,"Z")
    MArchP(point,0,-highZ1,-highZ2)
    DO(1,ON)
end

-- IO状态设置函数
function set_io_states(io_array, desired_state)
    for i, io_value in ipairs(io_array) do
        DO(io_value,desired_state)
    end
end

function drop(point)   

	-- 气缸关
    set_io_states(DO_airBox,"OFF")

	highZ1=RobotZ("Z")
    highZ2=ReadPoint(point,"Z")
    MArchP(point,0,-highZ1,-highZ2)

	set_io_states(DO_electroc,"OFF")

    set_io_states(DO_airBox,"ON")
	DELAY(0.2)

	set_io_states(DO_airBox,"OFF")
end


-- 分割数组xyr 到x,y,r
function split_put_array_xyr( station_xyr, s, x, y, r)
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
function split_pick_array_xyr( xyr, x, y, r)
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
    
    if received_array == nil then
        return
    end
    
    if #received_array == 0 then
        return
    end
    
    message_header[array_num] = received_array[1]
    camera_number[array_num] = tonumber(received_array[2])
    operating_mode[array_num] = tonumber(received_array[3])

    if operating_mode[array_num] == 2 then
        
        action_mode[array_num] = tonumber(received_array[4])
        reserved_variable[array_num] = tonumber(received_array[5])

        if array_num == 1 then
            clear_array(pick_positions_x)
            clear_array(pick_positions_y)
            clear_array(pick_positions_r)
            for i = 6, #received_array do
                pick_positions[i-5] = received_array[i]
            end
            split_array_xyr( pick_positions, pick_positions_x, pick_positions_y, pick_positions_r)
        end
        
        if array_num == 2 then
            clear_array(put_positions_x)
            clear_array(put_positions_y)
            clear_array(put_positions_r)
            for i = 6, #received_array do
                put_positions[i-5] = received_array[i]
            end
            split_array_xyr( put_positions, put_positions_x, put_positions_y, put_positions_r)
        end
    end
end


function task_pick_a_fishhook(i, type, air_num, electroc_num)
	robotOnPanel=1
	
	ChangeTF(i)
	
	--取左OK鱼钩
	if type=="LeftPosition" then
        x_offset=tonumber(LeftPosition[(LeftCountAll-LeftCount)*3+3])
        y_offset=tonumber(LeftPosition[(LeftCountAll-LeftCount)*3+4])
        r_offset=tonumber(LeftPosition[(LeftCountAll-LeftCount)*3+5])
        MArchP("GL_pick"+X(x_offset)+Y(y_offset)+Z(20)+RZ(r_offset),0,50,50)
        DO(air_num, ON)
        DELAY(pickDownDelay)
        
        print("LeftPosition,".."num:"..i..",x:"..x_offset..",y:"..y_offset..",r:"..r_offset)
        
        MovP("GL_pick"+X(x_offset)+Y(y_offset)+Z(0)+RZ(r_offset))

        DO(electroc_num, ON)
        DELAY(0.25)

        DO(air_num,OFF)
        DELAY(PickUp)

        ChangeTF(0)

        LeftCount=LeftCount-1
        Grip_Full[i]=1
	end

	--取右OK鱼钩
    if type=="RightPosition" then
        x_offset=tonumber(RightPosition[(RightCountAll-RightCount)*3+3])
        y_offset=tonumber(RightPosition[(RightCountAll-RightCount)*3+4])
        r_offset=tonumber(RightPosition[(RightCountAll-RightCount)*3+5])
        MArchP("GL_pick"+X(x_offset)+Y(y_offset)+Z(20)+RZ(r_offset),0,50,50)
        
        print("RightPosition,".."num:"..i..",x:"..x_offset..",y:"..y_offset..",r:"..r_offset)
        
        DO(airBox,ON)
        DELAY(pickDownDelay)
        MovP("GL_pick"+X(x_offset)+Y(y_offset)+Z(0)+RZ(r_offset))
        DO(electroc,ON)
        DELAY(0.25)
        DO(airBox,OFF)
        DELAY(PickUp)
        ChangeTF(0)
        RightCount=RightCount-1
        Grip_Full[i]=1
	end

	--取NG鱼钩
	if type=="NGPosition" then
        x_offset=tonumber(NGPosition[(NGCountAll-NGCount)*3+3])
        y_offset=tonumber(NGPosition[(NGCountAll-NGCount)*3+4])
        r_offset=tonumber(NGPosition[(NGCountAll-NGCount)*3+5])
        MArchP("GL_pick"+X(x_offset)+Y(y_offset)+RZ(r_offset),0,50,50)
        
        print("num:"..i..",x:"..x_offset..",y:"..y_offset..",r:"..r_offset)
        
        DO(airBox,ON)
        DELAY(pickDownDelay)
        DO(electroc,ON)
        DELAY(pickDownDelay)
        DO(airBox,OFF)
        DELAY(PickUp)
        ChangeTF(0)
        NGCount=NGCount-1
        Grip_Full[i]=1
	end
	--取Other鱼钩
	if type=="OtherPosition" then
        x_offset=tonumber(OtherPosition[(OtherCountAll-OtherCount)*3+3])
        y_offset=tonumber(OtherPosition[(OtherCountAll-OtherCount)*3+4])
        r_offset=tonumber(OtherPosition[(OtherCountAll-OtherCount)*3+5])
        MArchP("GL_pick"+X(x_offset)+Y(y_offset)+RZ(r_offset),0,50,50)
        
        print("num:"..i..",x:"..x_offset..",y:"..y_offset..",r:"..r_offset)
        
        DO(airBox,ON)
        DELAY(pickDownDelay)
        DO(electroc,ON)
        DO(airBox,OFF)
        DELAY(PickUp)
        ChangeTF(0)
        OtherCount=OtherCount-1
        Grip_Full[i]=1
	end

end

function sockettcp()
    -- 主机IP,端口号，间距，分隔符，cmd，睡眠时间，超时，tcp关闭。
    while status1~=0 or status2~=0 or status3~=0 or status4~=0 or status5~=0 or status6~=0  do  --0：连线成功，-1:连线失败，失败后尝试重新连接      
        PC1,status=SocketClass("192.168.101.200",7921,nil,nil,nil,nil,0.050,false) --左鱼钩字符串
        
        PC5,status=SocketClass("192.168.101.200",7925,nil,nil,nil,nil,0.050,false) --下相机纠偏鱼钩字符串
        PC6,status=SocketClass("192.168.101.200",7925,nil,nil,nil,nil,0.050,false) --发送指令       
    end

    LeftPositionTCP=nil
    RightPositionTCP=nil
    NGPositionTCP=nil
    OtherPositionTCP=nil
    OffsetPositionTCP=nil
    LeftPositionTCP=PC1:Receive()
  
    OffsetPositionTCP=PC5:Receive()
    if LeftPositionTCP~=nil then
        if LeftPositionTCP[1]=="LeftPosition" then
            LeftCountAll=tonumber(LeftPositionTCP[2])
            LeftCount=LeftCountAll
            LeftPosition=LeftPositionTCP
            --LeftPositionTCP=nil
            --OffsetStation=0
            robotOnPanel=1
        end
        if LeftPositionTCP[1]=="RightPosition" then
            RightCountAll=tonumber(LeftPositionTCP[2])
            RightCount=RightCountAll
            RightPosition=LeftPositionTCP
            
            RightPositionTCP = nil
            OffsetStation=0
            robotOnPanel=1
        end

        if LeftPositionTCP[1]=="NGPosition" then
            NGCountAll=tonumber(LeftPositionTCP[2])
            NGCount=NGCountAll
            NGPosition=LeftPositionTCP
            NGPositionTCP=nil
            --OffsetStation=0
            robotOnPanel=1
        end
        if LeftPositionTCP[1]=="OtherPosition" then
            OtherCountAll=tonumber(LeftPositionTCP[2])
            OtherCount=OtherCountAll
            OtherPosition=LeftPositionTCP
            OtherPositionTCP=nil
            --OffsetStation=0
            robotOnPanel=1
        end        
        LeftPositionTCP=nil
    end

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
end