package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
)

// ==================== 关联数据API（用于下拉框）====================

// 获取所有学校名称列表（用于下拉框）
func getSchoolNames(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name FROM school ORDER BY name")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var schools []map[string]interface{}
	for rows.Next() {
		var id int
		var name string
		if err := rows.Scan(&id, &name); err != nil {
			continue
		}
		schools = append(schools, map[string]interface{}{
			"id":   id,
			"name": name,
		})
	}
	sendSuccess(w, schools)
}

// 获取所有船舶名称列表（用于下拉框）
func getShipNames(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name FROM ship ORDER BY name")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var ships []map[string]interface{}
	for rows.Next() {
		var id int
		var name string
		if err := rows.Scan(&id, &name); err != nil {
			continue
		}
		ships = append(ships, map[string]interface{}{
			"id":   id,
			"name": name,
		})
	}
	sendSuccess(w, ships)
}

// ==================== 船员相关处理函数 ====================

func getCrewList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, region, age, education, graduation_school, status, position, previous_ships, current_ship, phone, height, weight, experience, is_professional FROM crew ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var crews []Crew
	for rows.Next() {
		var c Crew
		err := rows.Scan(&c.ID, &c.Name, &c.Region, &c.Age, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.PreviousShips, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional)
		if err != nil {
			continue
		}
		crews = append(crews, c)
	}
	sendSuccess(w, crews)
}

func getCrew(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var c Crew
	err = db.QueryRow("SELECT id, name, region, age, education, graduation_school, status, position, previous_ships, current_ship, phone, height, weight, experience, is_professional FROM crew WHERE id = ?", id).
		Scan(&c.ID, &c.Name, &c.Region, &c.Age, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.PreviousShips, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "船员不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	sendSuccess(w, c)
}

func createCrew(w http.ResponseWriter, r *http.Request) {
	var c Crew
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO crew (name, region, age, education, graduation_school, status, position, previous_ships, current_ship, phone, height, weight, experience, is_professional) 
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		c.Name, c.Region, c.Age, c.Education, c.GraduationSchool, c.Status, c.Position, c.PreviousShips, c.CurrentShip, c.Phone, c.Height, c.Weight, c.Experience, c.IsProfessional)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "创建失败: "+err.Error())
		return
	}

	id, _ := result.LastInsertId()
	c.ID = int(id)
	sendSuccess(w, c)
}

func updateCrew(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var c Crew
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	_, err = db.Exec(`UPDATE crew SET name=?, region=?, age=?, education=?, graduation_school=?, status=?, position=?, previous_ships=?, current_ship=?, phone=?, height=?, weight=?, experience=?, is_professional=? WHERE id=?`,
		c.Name, c.Region, c.Age, c.Education, c.GraduationSchool, c.Status, c.Position, c.PreviousShips, c.CurrentShip, c.Phone, c.Height, c.Weight, c.Experience, c.IsProfessional, id)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "更新失败: "+err.Error())
		return
	}

	c.ID = id
	sendSuccess(w, c)
}

func deleteCrew(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	_, err = db.Exec("DELETE FROM crew WHERE id = ?", id)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "删除失败: "+err.Error())
		return
	}

	sendSuccess(w, map[string]string{"message": "删除成功"})
}

func searchCrew(w http.ResponseWriter, r *http.Request) {
	keyword := r.URL.Query().Get("keyword")
	query := "SELECT id, name, region, age, education, graduation_school, status, position, previous_ships, current_ship, phone, height, weight, experience, is_professional FROM crew"
	searchFields := []string{"name", "region", "education", "graduation_school", "status", "position", "previous_ships", "current_ship", "phone", "experience"}

	sqlQuery, args := buildSearchQuery(query, keyword, searchFields)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
		return
	}
	defer rows.Close()

	var crews []Crew
	for rows.Next() {
		var c Crew
		rows.Scan(&c.ID, &c.Name, &c.Region, &c.Age, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.PreviousShips, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional)
		crews = append(crews, c)
	}
	sendSuccess(w, crews)
}

func filterCrew(w http.ResponseWriter, r *http.Request) {
	var filters map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&filters); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	query := "SELECT id, name, region, age, education, graduation_school, status, position, previous_ships, current_ship, phone, height, weight, experience, is_professional FROM crew"
	sqlQuery, args := buildFilterQuery(query, filters)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "筛选失败: "+err.Error())
		return
	}
	defer rows.Close()

	var crews []Crew
	for rows.Next() {
		var c Crew
		rows.Scan(&c.ID, &c.Name, &c.Region, &c.Age, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.PreviousShips, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional)
		crews = append(crews, c)
	}
	sendSuccess(w, crews)
}

// ==================== 船舶相关处理函数 ====================

func getShipList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, ship_age, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status FROM ship ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var ships []Ship
	for rows.Next() {
		var s Ship
		rows.Scan(&s.ID, &s.Name, &s.ShipAge, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus)
		ships = append(ships, s)
	}
	sendSuccess(w, ships)
}

func getShip(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var s Ship
	err = db.QueryRow("SELECT id, name, ship_age, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status FROM ship WHERE id = ?", id).
		Scan(&s.ID, &s.Name, &s.ShipAge, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "船舶不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	sendSuccess(w, s)
}

func createShip(w http.ResponseWriter, r *http.Request) {
	var s Ship
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO ship (name, ship_age, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status) 
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		s.Name, s.ShipAge, s.ShipClass, s.OwnerCompany, s.CrewCompany, s.EngineModel, s.Power, s.GrossTonnage, s.DeadweightTonnage, s.PortOfRegistry, s.ShipCondition, s.SalaryStatus)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "创建失败: "+err.Error())
		return
	}

	id, _ := result.LastInsertId()
	s.ID = int(id)
	sendSuccess(w, s)
}

func updateShip(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var s Ship
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	_, err = db.Exec(`UPDATE ship SET name=?, ship_age=?, ship_class=?, owner_company=?, crew_company=?, engine_model=?, power=?, gross_tonnage=?, deadweight_tonnage=?, port_of_registry=?, ship_condition=?, salary_status=? WHERE id=?`,
		s.Name, s.ShipAge, s.ShipClass, s.OwnerCompany, s.CrewCompany, s.EngineModel, s.Power, s.GrossTonnage, s.DeadweightTonnage, s.PortOfRegistry, s.ShipCondition, s.SalaryStatus, id)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "更新失败: "+err.Error())
		return
	}

	s.ID = id
	sendSuccess(w, s)
}

func deleteShip(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	_, err = db.Exec("DELETE FROM ship WHERE id = ?", id)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "删除失败: "+err.Error())
		return
	}

	sendSuccess(w, map[string]string{"message": "删除成功"})
}

func searchShip(w http.ResponseWriter, r *http.Request) {
	keyword := r.URL.Query().Get("keyword")
	query := "SELECT id, name, ship_age, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status FROM ship"
	searchFields := []string{"name", "ship_class", "owner_company", "crew_company", "engine_model", "port_of_registry", "ship_condition", "salary_status"}

	sqlQuery, args := buildSearchQuery(query, keyword, searchFields)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
		return
	}
	defer rows.Close()

	var ships []Ship
	for rows.Next() {
		var s Ship
		rows.Scan(&s.ID, &s.Name, &s.ShipAge, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus)
		ships = append(ships, s)
	}
	sendSuccess(w, ships)
}

func filterShip(w http.ResponseWriter, r *http.Request) {
	var filters map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&filters); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	query := "SELECT id, name, ship_age, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status FROM ship"
	sqlQuery, args := buildFilterQuery(query, filters)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "筛选失败: "+err.Error())
		return
	}
	defer rows.Close()

	var ships []Ship
	for rows.Next() {
		var s Ship
		rows.Scan(&s.ID, &s.Name, &s.ShipAge, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus)
		ships = append(ships, s)
	}
	sendSuccess(w, ships)
}

// ==================== 学校相关处理函数 ====================

func getSchoolList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, address, admission_phone, level, other_info FROM school ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var schools []School
	for rows.Next() {
		var s School
		rows.Scan(&s.ID, &s.Name, &s.Address, &s.AdmissionPhone, &s.Level, &s.OtherInfo)
		schools = append(schools, s)
	}
	sendSuccess(w, schools)
}

func getSchool(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var s School
	err = db.QueryRow("SELECT id, name, address, admission_phone, level, other_info FROM school WHERE id = ?", id).
		Scan(&s.ID, &s.Name, &s.Address, &s.AdmissionPhone, &s.Level, &s.OtherInfo)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "学校不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	sendSuccess(w, s)
}

func createSchool(w http.ResponseWriter, r *http.Request) {
	var s School
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO school (name, address, admission_phone, level, other_info) VALUES (?, ?, ?, ?, ?)`,
		s.Name, s.Address, s.AdmissionPhone, s.Level, s.OtherInfo)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "创建失败: "+err.Error())
		return
	}

	id, _ := result.LastInsertId()
	s.ID = int(id)
	sendSuccess(w, s)
}

func updateSchool(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var s School
	if err := json.NewDecoder(r.Body).Decode(&s); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	_, err = db.Exec(`UPDATE school SET name=?, address=?, admission_phone=?, level=?, other_info=? WHERE id=?`,
		s.Name, s.Address, s.AdmissionPhone, s.Level, s.OtherInfo, id)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "更新失败: "+err.Error())
		return
	}

	s.ID = id
	sendSuccess(w, s)
}

func deleteSchool(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	_, err = db.Exec("DELETE FROM school WHERE id = ?", id)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "删除失败: "+err.Error())
		return
	}

	sendSuccess(w, map[string]string{"message": "删除成功"})
}

func searchSchool(w http.ResponseWriter, r *http.Request) {
	keyword := r.URL.Query().Get("keyword")
	query := "SELECT id, name, address, admission_phone, level, other_info FROM school"
	searchFields := []string{"name", "address", "admission_phone", "level", "other_info"}

	sqlQuery, args := buildSearchQuery(query, keyword, searchFields)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
		return
	}
	defer rows.Close()

	var schools []School
	for rows.Next() {
		var s School
		rows.Scan(&s.ID, &s.Name, &s.Address, &s.AdmissionPhone, &s.Level, &s.OtherInfo)
		schools = append(schools, s)
	}
	sendSuccess(w, schools)
}

func filterSchool(w http.ResponseWriter, r *http.Request) {
	var filters map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&filters); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	query := "SELECT id, name, address, admission_phone, level, other_info FROM school"
	sqlQuery, args := buildFilterQuery(query, filters)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "筛选失败: "+err.Error())
		return
	}
	defer rows.Close()

	var schools []School
	for rows.Next() {
		var s School
		rows.Scan(&s.ID, &s.Name, &s.Address, &s.AdmissionPhone, &s.Level, &s.OtherInfo)
		schools = append(schools, s)
	}
	sendSuccess(w, schools)
}

// ==================== 船公司相关处理函数 ====================

func getCompanyList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, address, ships, contact_phone FROM company ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var companies []Company
	for rows.Next() {
		var c Company
		rows.Scan(&c.ID, &c.Name, &c.Address, &c.Ships, &c.ContactPhone)
		companies = append(companies, c)
	}
	sendSuccess(w, companies)
}

func getCompany(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var c Company
	err = db.QueryRow("SELECT id, name, address, ships, contact_phone FROM company WHERE id = ?", id).
		Scan(&c.ID, &c.Name, &c.Address, &c.Ships, &c.ContactPhone)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "船公司不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	sendSuccess(w, c)
}

func createCompany(w http.ResponseWriter, r *http.Request) {
	var c Company
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO company (name, address, ships, contact_phone) VALUES (?, ?, ?, ?)`,
		c.Name, c.Address, c.Ships, c.ContactPhone)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "创建失败: "+err.Error())
		return
	}

	id, _ := result.LastInsertId()
	c.ID = int(id)
	sendSuccess(w, c)
}

func updateCompany(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var c Company
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	_, err = db.Exec(`UPDATE company SET name=?, address=?, ships=?, contact_phone=? WHERE id=?`,
		c.Name, c.Address, c.Ships, c.ContactPhone, id)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "更新失败: "+err.Error())
		return
	}

	c.ID = id
	sendSuccess(w, c)
}

func deleteCompany(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	_, err = db.Exec("DELETE FROM company WHERE id = ?", id)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "删除失败: "+err.Error())
		return
	}

	sendSuccess(w, map[string]string{"message": "删除成功"})
}

func searchCompany(w http.ResponseWriter, r *http.Request) {
	keyword := r.URL.Query().Get("keyword")
	query := "SELECT id, name, address, ships, contact_phone FROM company"
	searchFields := []string{"name", "address", "ships", "contact_phone"}

	sqlQuery, args := buildSearchQuery(query, keyword, searchFields)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
		return
	}
	defer rows.Close()

	var companies []Company
	for rows.Next() {
		var c Company
		rows.Scan(&c.ID, &c.Name, &c.Address, &c.Ships, &c.ContactPhone)
		companies = append(companies, c)
	}
	sendSuccess(w, companies)
}

func filterCompany(w http.ResponseWriter, r *http.Request) {
	var filters map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&filters); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	query := "SELECT id, name, address, ships, contact_phone FROM company"
	sqlQuery, args := buildFilterQuery(query, filters)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "筛选失败: "+err.Error())
		return
	}
	defer rows.Close()

	var companies []Company
	for rows.Next() {
		var c Company
		rows.Scan(&c.ID, &c.Name, &c.Address, &c.Ships, &c.ContactPhone)
		companies = append(companies, c)
	}
	sendSuccess(w, companies)
}

// ==================== 管理公司相关处理函数 ====================

func getManagementList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, address, managed_ships, reputation, salary_status, contact_phone FROM management ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var managements []Management
	for rows.Next() {
		var m Management
		rows.Scan(&m.ID, &m.Name, &m.Address, &m.ManagedShips, &m.Reputation, &m.SalaryStatus, &m.ContactPhone)
		managements = append(managements, m)
	}
	sendSuccess(w, managements)
}

func getManagement(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var m Management
	err = db.QueryRow("SELECT id, name, address, managed_ships, reputation, salary_status, contact_phone FROM management WHERE id = ?", id).
		Scan(&m.ID, &m.Name, &m.Address, &m.ManagedShips, &m.Reputation, &m.SalaryStatus, &m.ContactPhone)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "管理公司不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	sendSuccess(w, m)
}

func createManagement(w http.ResponseWriter, r *http.Request) {
	var m Management
	if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO management (name, address, managed_ships, reputation, salary_status, contact_phone) VALUES (?, ?, ?, ?, ?, ?)`,
		m.Name, m.Address, m.ManagedShips, m.Reputation, m.SalaryStatus, m.ContactPhone)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "创建失败: "+err.Error())
		return
	}

	id, _ := result.LastInsertId()
	m.ID = int(id)
	sendSuccess(w, m)
}

func updateManagement(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	var m Management
	if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	_, err = db.Exec(`UPDATE management SET name=?, address=?, managed_ships=?, reputation=?, salary_status=?, contact_phone=? WHERE id=?`,
		m.Name, m.Address, m.ManagedShips, m.Reputation, m.SalaryStatus, m.ContactPhone, id)

	if err != nil {
		sendError(w, http.StatusInternalServerError, "更新失败: "+err.Error())
		return
	}

	m.ID = id
	sendSuccess(w, m)
}

func deleteManagement(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		sendError(w, http.StatusBadRequest, "无效的ID")
		return
	}

	_, err = db.Exec("DELETE FROM management WHERE id = ?", id)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "删除失败: "+err.Error())
		return
	}

	sendSuccess(w, map[string]string{"message": "删除成功"})
}

func searchManagement(w http.ResponseWriter, r *http.Request) {
	keyword := r.URL.Query().Get("keyword")
	query := "SELECT id, name, address, managed_ships, reputation, salary_status, contact_phone FROM management"
	searchFields := []string{"name", "address", "managed_ships", "reputation", "salary_status", "contact_phone"}

	sqlQuery, args := buildSearchQuery(query, keyword, searchFields)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
		return
	}
	defer rows.Close()

	var managements []Management
	for rows.Next() {
		var m Management
		rows.Scan(&m.ID, &m.Name, &m.Address, &m.ManagedShips, &m.Reputation, &m.SalaryStatus, &m.ContactPhone)
		managements = append(managements, m)
	}
	sendSuccess(w, managements)
}

func filterManagement(w http.ResponseWriter, r *http.Request) {
	var filters map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&filters); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	query := "SELECT id, name, address, managed_ships, reputation, salary_status, contact_phone FROM management"
	sqlQuery, args := buildFilterQuery(query, filters)
	sqlQuery += " ORDER BY id DESC"

	rows, err := db.Query(sqlQuery, args...)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "筛选失败: "+err.Error())
		return
	}
	defer rows.Close()

	var managements []Management
	for rows.Next() {
		var m Management
		rows.Scan(&m.ID, &m.Name, &m.Address, &m.ManagedShips, &m.Reputation, &m.SalaryStatus, &m.ContactPhone)
		managements = append(managements, m)
	}
	sendSuccess(w, managements)
}
