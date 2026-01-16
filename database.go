package main

import (
	"fmt"
)

// 初始化数据库表
func initTables() {
	tables := []string{
		createCrewTable(),
		createShipTable(),
		createSchoolTable(),
		createCompanyTable(),
		createManagementTable(),
	}

	for _, sql := range tables {
		if _, err := db.Exec(sql); err != nil {
			fmt.Printf("创建表失败: %v\n", err)
		}
	}
	fmt.Println("数据库表初始化完成")
}

// 创建船员表
func createCrewTable() string {
	return `CREATE TABLE IF NOT EXISTS crew (
		id INT AUTO_INCREMENT PRIMARY KEY,
		name VARCHAR(100) COMMENT '姓名',
		region VARCHAR(100) COMMENT '地区',
		age INT COMMENT '年龄',
		education VARCHAR(50) COMMENT '学历',
		graduation_school VARCHAR(200) COMMENT '毕业学校',
		status VARCHAR(50) COMMENT '状态',
		position VARCHAR(100) COMMENT '职务',
		previous_ships TEXT COMMENT '过往就职船舶',
		current_ship VARCHAR(200) COMMENT '现就职船舶',
		phone VARCHAR(20) COMMENT '电话',
		height INT COMMENT '身高(cm)',
		weight INT COMMENT '体重(kg)',
		experience TEXT COMMENT '资历',
		is_professional TINYINT(1) DEFAULT 0 COMMENT '是否科班',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		INDEX idx_name (name),
		INDEX idx_region (region),
		INDEX idx_status (status),
		INDEX idx_position (position),
		INDEX idx_graduation_school (graduation_school),
		INDEX idx_current_ship (current_ship)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='船员表';`
}

// 创建船舶表
func createShipTable() string {
	return `CREATE TABLE IF NOT EXISTS ship (
		id INT AUTO_INCREMENT PRIMARY KEY,
		name VARCHAR(200) COMMENT '船名',
		ship_age INT COMMENT '船龄',
		ship_class VARCHAR(100) COMMENT '船级',
		owner_company VARCHAR(200) COMMENT '所属公司',
		crew_company VARCHAR(200) COMMENT '派员公司',
		engine_model VARCHAR(200) COMMENT '主机型号',
		power VARCHAR(100) COMMENT '功率',
		gross_tonnage VARCHAR(100) COMMENT '总吨',
		deadweight_tonnage VARCHAR(100) COMMENT '载重吨',
		port_of_registry VARCHAR(100) COMMENT '船籍港',
		ship_condition VARCHAR(100) COMMENT '船况',
		salary_status VARCHAR(100) COMMENT '工资发放情况',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		INDEX idx_name (name),
		INDEX idx_owner_company (owner_company),
		INDEX idx_crew_company (crew_company)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='船舶表';`
}

// 创建学校表
func createSchoolTable() string {
	return `CREATE TABLE IF NOT EXISTS school (
		id INT AUTO_INCREMENT PRIMARY KEY,
		name VARCHAR(200) COMMENT '名称',
		address VARCHAR(500) COMMENT '地址',
		admission_phone VARCHAR(20) COMMENT '招生电话',
		level VARCHAR(100) COMMENT '级别',
		other_info TEXT COMMENT '其他信息',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		INDEX idx_name (name),
		INDEX idx_level (level)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='学校表';`
}

// 创建船公司表
func createCompanyTable() string {
	return `CREATE TABLE IF NOT EXISTS company (
		id INT AUTO_INCREMENT PRIMARY KEY,
		name VARCHAR(200) COMMENT '公司名',
		address VARCHAR(500) COMMENT '地址',
		ships TEXT COMMENT '拥有船舶',
		contact_phone VARCHAR(20) COMMENT '联系电话',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		INDEX idx_name (name)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='船公司表';`
}

// 创建管理公司表
func createManagementTable() string {
	return `CREATE TABLE IF NOT EXISTS management (
		id INT AUTO_INCREMENT PRIMARY KEY,
		name VARCHAR(200) COMMENT '公司名',
		address VARCHAR(500) COMMENT '地址',
		managed_ships TEXT COMMENT '管理船舶',
		reputation VARCHAR(100) COMMENT '信誉度',
		salary_status VARCHAR(100) COMMENT '工资发放情况',
		contact_phone VARCHAR(20) COMMENT '联系电话',
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
		updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		INDEX idx_name (name),
		INDEX idx_reputation (reputation)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='管理公司表';`
}
