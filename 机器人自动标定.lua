
biaoding_flag = 0 --标定判断，0：不标定
tumo_delay = 30 * 1000
biaoding_delay = 2 * 1000


function is_biaoding()
	--Modbus判断
	--biaoding_flag = ReadModbus(0x3100, "DW")

	--IO判断
	-- if DI(xxx) == ON then
	-- 	biaoding_flag = 1
	-- else
    --     biaoding_flag = 0
    -- end
end

--粉圈  标定前  抛料
function  fenquan_pao()
    for i = 7, 10, 1 do
        DO(i,ON)
        DO(i,OFF)
    end
end

--标定 走点位
function point_move(point)
    highZ1=RobotZ("Z")  --当前Z
	MArchP(point - Z(point), 0, -highZ1, 0, 10) --移动到点位上方
	DELAY(tumo_delay) --延时涂墨
	MovL(point,10) --到位
    DELAY(biaoding_delay)
    MovL(point+Z(10),10)
end

function biaoding_pick()

	safetyPoint() --回安全位
	WAIT(DI,{3,4,5,6},{ON,ON,ON,ON})
    
    fenquan_pao() --抛料
	
    DO(3,ON) --1号夹爪气缸打开

	point_move(point1)
    point_move(point2)
    point_move(point3)
    point_move(point4)

    --偏移
    point_move(point_dx_dy)
    DO(3,OFF)

    DO(4,ON)
    point_move(point_dx_dy)
    DO(4,OFF)

    DO(5,ON)
    point_move(point_dx_dy)
    DO(5,OFF)

    DO(6,ON)
    point_move(point_dx_dy)
    DO(6,OFF)
    
    safetyPoint() --回安全位
    biaoding_flag = 0
end
