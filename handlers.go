package main

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"
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

// 获取所有船公司名称列表（用于下拉框）
func getCompanyNames(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name FROM company ORDER BY name")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var companies []map[string]interface{}
	for rows.Next() {
		var id int
		var name string
		if err := rows.Scan(&id, &name); err != nil {
			continue
		}
		companies = append(companies, map[string]interface{}{
			"id":   id,
			"name": name,
		})
	}
	sendSuccess(w, companies)
}

// 获取所有管理公司名称列表（用于下拉框）
func getManagementNames(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name FROM management ORDER BY name")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var managements []map[string]interface{}
	for rows.Next() {
		var id int
		var name string
		if err := rows.Scan(&id, &name); err != nil {
			continue
		}
		managements = append(managements, map[string]interface{}{
			"id":   id,
			"name": name,
		})
	}
	sendSuccess(w, managements)
}

// ==================== 船员相关处理函数 ====================

func getCrewList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, region, birth_date, education, graduation_school, status, position, current_ship, phone, height, weight, experience, is_professional, colleague_evaluation, company_evaluation, remark FROM crew ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var crews []Crew
	for rows.Next() {
		var c Crew
		err := rows.Scan(&c.ID, &c.Name, &c.Region, &c.BirthDate, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional, &c.ColleagueEvaluation, &c.CompanyEvaluation, &c.Remark)
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
	err = db.QueryRow("SELECT id, name, region, birth_date, education, graduation_school, status, position, current_ship, phone, height, weight, experience, is_professional, colleague_evaluation, company_evaluation, remark FROM crew WHERE id = ?", id).
		Scan(&c.ID, &c.Name, &c.Region, &c.BirthDate, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional, &c.ColleagueEvaluation, &c.CompanyEvaluation, &c.Remark)

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

	result, err := db.Exec(`INSERT INTO crew (name, region, birth_date, education, graduation_school, status, position, current_ship, phone, height, weight, experience, is_professional, colleague_evaluation, company_evaluation, remark) 
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		c.Name, c.Region, c.BirthDate, c.Education, c.GraduationSchool, c.Status, c.Position, c.CurrentShip, c.Phone, c.Height, c.Weight, c.Experience, c.IsProfessional, c.ColleagueEvaluation, c.CompanyEvaluation, c.Remark)

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

	_, err = db.Exec(`UPDATE crew SET name=?, region=?, birth_date=?, education=?, graduation_school=?, status=?, position=?, current_ship=?, phone=?, height=?, weight=?, experience=?, is_professional=?, colleague_evaluation=?, company_evaluation=?, remark=? WHERE id=?`,
		c.Name, c.Region, c.BirthDate, c.Education, c.GraduationSchool, c.Status, c.Position, c.CurrentShip, c.Phone, c.Height, c.Weight, c.Experience, c.IsProfessional, c.ColleagueEvaluation, c.CompanyEvaluation, c.Remark, id)

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
	query := "SELECT id, name, region, birth_date, education, graduation_school, status, position, current_ship, phone, height, weight, experience, is_professional, colleague_evaluation, company_evaluation, remark FROM crew"

	// 检查关键词是否包含多个船名（逗号分隔）
	searchShips := []string{}
	if keyword != "" {
		// 尝试将关键词按逗号分割，检查是否是多个船名
		parts := strings.Split(keyword, ",")
		if len(parts) > 1 {
			// 如果包含逗号，认为是多个船名搜索
			for _, part := range parts {
				trimmed := strings.TrimSpace(part)
				if trimmed != "" {
					searchShips = append(searchShips, trimmed)
				}
			}
		}
	}

	var crews []Crew
	if len(searchShips) > 0 {
		// 多船搜索：需要检查current_ship字段是否包含所有搜索的船名
		// 先获取所有船员，然后在内存中过滤
		rows, err := db.Query(query + " ORDER BY id DESC")
		if err != nil {
			sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
			return
		}
		defer rows.Close()

		for rows.Next() {
			var c Crew
			rows.Scan(&c.ID, &c.Name, &c.Region, &c.BirthDate, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional, &c.ColleagueEvaluation, &c.CompanyEvaluation, &c.Remark)
			// 检查是否包含所有搜索的船名
			if containsAllShips(c.CurrentShip, searchShips) {
				crews = append(crews, c)
			}
		}
	} else {
		// 普通搜索
		searchFields := []string{"name", "region", "education", "graduation_school", "status", "position", "current_ship", "phone", "experience", "colleague_evaluation", "company_evaluation", "remark"}
		sqlQuery, args := buildSearchQuery(query, keyword, searchFields)
		sqlQuery += " ORDER BY id DESC"

		rows, err := db.Query(sqlQuery, args...)
		if err != nil {
			sendError(w, http.StatusInternalServerError, "搜索失败: "+err.Error())
			return
		}
		defer rows.Close()

		for rows.Next() {
			var c Crew
			rows.Scan(&c.ID, &c.Name, &c.Region, &c.BirthDate, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional, &c.ColleagueEvaluation, &c.CompanyEvaluation, &c.Remark)
			crews = append(crews, c)
		}
	}

	sendSuccess(w, crews)
}

func filterCrew(w http.ResponseWriter, r *http.Request) {
	var filters map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&filters); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	query := "SELECT id, name, region, birth_date, education, graduation_school, status, position, current_ship, phone, height, weight, experience, is_professional, colleague_evaluation, company_evaluation, remark FROM crew"

	// 检查是否有current_ship筛选条件，且包含多个船名
	var searchShips []string
	currentShipFilter, hasShipFilter := filters["current_ship"]
	if hasShipFilter {
		if strValue, ok := currentShipFilter.(string); ok && strValue != "" {
			// 检查是否包含逗号（多个船名）
			parts := strings.Split(strValue, ",")
			if len(parts) > 1 {
				for _, part := range parts {
					trimmed := strings.TrimSpace(part)
					if trimmed != "" {
						searchShips = append(searchShips, trimmed)
					}
				}
			}
		}
	}

	// 如果有多个船名筛选，需要特殊处理
	if len(searchShips) > 0 {
		// 先移除current_ship筛选，构建其他条件的查询
		otherFilters := make(map[string]interface{})
		for k, v := range filters {
			if k != "current_ship" {
				otherFilters[k] = v
			}
		}

		sqlQuery, args := buildFilterQuery(query, otherFilters)
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
			rows.Scan(&c.ID, &c.Name, &c.Region, &c.BirthDate, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional, &c.ColleagueEvaluation, &c.CompanyEvaluation, &c.Remark)
			// 检查是否包含所有搜索的船名
			if containsAllShips(c.CurrentShip, searchShips) {
				crews = append(crews, c)
			}
		}
		sendSuccess(w, crews)
	} else {
		// 普通筛选
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
			rows.Scan(&c.ID, &c.Name, &c.Region, &c.BirthDate, &c.Education, &c.GraduationSchool, &c.Status, &c.Position, &c.CurrentShip, &c.Phone, &c.Height, &c.Weight, &c.Experience, &c.IsProfessional, &c.ColleagueEvaluation, &c.CompanyEvaluation, &c.Remark)
			crews = append(crews, c)
		}
		sendSuccess(w, crews)
	}
}

// ==================== 船舶相关处理函数 ====================

func getShipList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, build_date, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status, living_expense, has_pension, can_open_seal, personnel_phone, ship_phone, company_type, remark FROM ship ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var ships []Ship
	for rows.Next() {
		var s Ship
		rows.Scan(&s.ID, &s.Name, &s.BuildDate, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus, &s.LivingExpense, &s.HasPension, &s.CanOpenSeal, &s.PersonnelPhone, &s.ShipPhone, &s.CompanyType, &s.Remark)
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
	err = db.QueryRow("SELECT id, name, build_date, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status, living_expense, has_pension, can_open_seal, personnel_phone, ship_phone, company_type, remark FROM ship WHERE id = ?", id).
		Scan(&s.ID, &s.Name, &s.BuildDate, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus, &s.LivingExpense, &s.HasPension, &s.CanOpenSeal, &s.PersonnelPhone, &s.ShipPhone, &s.CompanyType, &s.Remark)

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

	result, err := db.Exec(`INSERT INTO ship (name, build_date, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status, living_expense, has_pension, can_open_seal, personnel_phone, ship_phone, company_type, remark) 
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		s.Name, s.BuildDate, s.ShipClass, s.OwnerCompany, s.CrewCompany, s.EngineModel, s.Power, s.GrossTonnage, s.DeadweightTonnage, s.PortOfRegistry, s.ShipCondition, s.SalaryStatus, s.LivingExpense, s.HasPension, s.CanOpenSeal, s.PersonnelPhone, s.ShipPhone, s.CompanyType, s.Remark)

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

	_, err = db.Exec(`UPDATE ship SET name=?, build_date=?, ship_class=?, owner_company=?, crew_company=?, engine_model=?, power=?, gross_tonnage=?, deadweight_tonnage=?, port_of_registry=?, ship_condition=?, salary_status=?, living_expense=?, has_pension=?, can_open_seal=?, personnel_phone=?, ship_phone=?, company_type=?, remark=? WHERE id=?`,
		s.Name, s.BuildDate, s.ShipClass, s.OwnerCompany, s.CrewCompany, s.EngineModel, s.Power, s.GrossTonnage, s.DeadweightTonnage, s.PortOfRegistry, s.ShipCondition, s.SalaryStatus, s.LivingExpense, s.HasPension, s.CanOpenSeal, s.PersonnelPhone, s.ShipPhone, s.CompanyType, s.Remark, id)

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

	// 先获取要删除的船舶名称
	var shipName string
	err = db.QueryRow("SELECT name FROM ship WHERE id = ?", id).Scan(&shipName)
	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "船舶不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询船舶失败: "+err.Error())
		return
	}

	// 查找所有在职船舶包含该船舶的船员
	rows, err := db.Query("SELECT id, current_ship FROM crew WHERE current_ship LIKE ?", "%"+shipName+"%")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询船员失败: "+err.Error())
		return
	}
	defer rows.Close()

	// 更新每个船员的在职船舶，去掉该船舶名称
	for rows.Next() {
		var crewID int
		var currentShip string
		if err := rows.Scan(&crewID, &currentShip); err != nil {
			continue
		}

		// 从船名列表中移除该船舶
		updatedShips := removeShipFromList(currentShip, shipName)
		
		// 更新船员的在职船舶
		_, err = db.Exec("UPDATE crew SET current_ship = ? WHERE id = ?", updatedShips, crewID)
		if err != nil {
			// 记录错误但继续处理其他船员
			continue
		}
	}

	// 删除船舶
	_, err = db.Exec("DELETE FROM ship WHERE id = ?", id)
	if err != nil {
		sendError(w, http.StatusInternalServerError, "删除失败: "+err.Error())
		return
	}

	sendSuccess(w, map[string]string{"message": "删除成功"})
}

// 从船名列表中移除指定的船舶名称
func removeShipFromList(shipList string, shipToRemove string) string {
	if shipList == "" {
		return ""
	}

	// 将船名列表按逗号分割
	ships := strings.Split(shipList, ",")
	var updatedShips []string

	for _, ship := range ships {
		trimmedShip := strings.TrimSpace(ship)
		// 如果船名不匹配（忽略大小写和空格），则保留
		if strings.ToLower(trimmedShip) != strings.ToLower(strings.TrimSpace(shipToRemove)) && trimmedShip != "" {
			updatedShips = append(updatedShips, trimmedShip)
		}
	}

	// 重新组合为逗号分隔的字符串
	return strings.Join(updatedShips, ", ")
}

func searchShip(w http.ResponseWriter, r *http.Request) {
	keyword := r.URL.Query().Get("keyword")
	query := "SELECT id, name, build_date, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status, living_expense, has_pension, can_open_seal, personnel_phone, ship_phone, company_type, remark FROM ship"
	searchFields := []string{"name", "ship_class", "owner_company", "crew_company", "engine_model", "port_of_registry", "ship_condition", "salary_status", "living_expense", "personnel_phone", "ship_phone", "company_type", "remark"}

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
		rows.Scan(&s.ID, &s.Name, &s.BuildDate, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus, &s.LivingExpense, &s.HasPension, &s.CanOpenSeal, &s.PersonnelPhone, &s.ShipPhone, &s.CompanyType, &s.Remark)
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

	query := "SELECT id, name, build_date, ship_class, owner_company, crew_company, engine_model, power, gross_tonnage, deadweight_tonnage, port_of_registry, ship_condition, salary_status, living_expense, has_pension, can_open_seal, personnel_phone, ship_phone, company_type, remark FROM ship"
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
		rows.Scan(&s.ID, &s.Name, &s.BuildDate, &s.ShipClass, &s.OwnerCompany, &s.CrewCompany, &s.EngineModel, &s.Power, &s.GrossTonnage, &s.DeadweightTonnage, &s.PortOfRegistry, &s.ShipCondition, &s.SalaryStatus, &s.LivingExpense, &s.HasPension, &s.CanOpenSeal, &s.PersonnelPhone, &s.ShipPhone, &s.CompanyType, &s.Remark)
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

// 查询公司拥有的船舶（根据owner_company字段）
func getCompanyShips(companyName string) []string {
	if companyName == "" {
		return []string{}
	}
	rows, err := db.Query("SELECT name FROM ship WHERE owner_company = ? ORDER BY name", companyName)
	if err != nil {
		return []string{}
	}
	defer rows.Close()

	var ships []string
	for rows.Next() {
		var shipName string
		if err := rows.Scan(&shipName); err != nil {
			continue
		}
		ships = append(ships, shipName)
	}
	return ships
}

func getCompanyList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, address, contact_phone, remark FROM company ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var companies []Company
	for rows.Next() {
		var c Company
		rows.Scan(&c.ID, &c.Name, &c.Address, &c.ContactPhone, &c.Remark)
		c.Ships = getCompanyShips(c.Name)
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
	err = db.QueryRow("SELECT id, name, address, contact_phone, remark FROM company WHERE id = ?", id).
		Scan(&c.ID, &c.Name, &c.Address, &c.ContactPhone, &c.Remark)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "船公司不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	c.Ships = getCompanyShips(c.Name)
	sendSuccess(w, c)
}

func createCompany(w http.ResponseWriter, r *http.Request) {
	var c Company
	if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO company (name, address, contact_phone, remark) VALUES (?, ?, ?, ?)`,
		c.Name, c.Address, c.ContactPhone, c.Remark)

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

	_, err = db.Exec(`UPDATE company SET name=?, address=?, contact_phone=?, remark=? WHERE id=?`,
		c.Name, c.Address, c.ContactPhone, c.Remark, id)

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
	query := "SELECT id, name, address, contact_phone, remark FROM company"
	searchFields := []string{"name", "address", "contact_phone", "remark"}

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
		rows.Scan(&c.ID, &c.Name, &c.Address, &c.ContactPhone, &c.Remark)
		c.Ships = getCompanyShips(c.Name)
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

	query := "SELECT id, name, address, contact_phone, remark FROM company"
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
		rows.Scan(&c.ID, &c.Name, &c.Address, &c.ContactPhone, &c.Remark)
		c.Ships = getCompanyShips(c.Name)
		companies = append(companies, c)
	}
	sendSuccess(w, companies)
}

// ==================== 管理公司相关处理函数 ====================

// 查询管理公司管理的船舶（根据crew_company字段）
func getManagementShips(managementName string) []string {
	if managementName == "" {
		return []string{}
	}
	rows, err := db.Query("SELECT name FROM ship WHERE crew_company = ? ORDER BY name", managementName)
	if err != nil {
		return []string{}
	}
	defer rows.Close()

	var ships []string
	for rows.Next() {
		var shipName string
		if err := rows.Scan(&shipName); err != nil {
			continue
		}
		ships = append(ships, shipName)
	}
	return ships
}

func getManagementList(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, address, reputation, salary_status, contact_phone, remark FROM management ORDER BY id DESC")
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	defer rows.Close()

	var managements []Management
	for rows.Next() {
		var m Management
		rows.Scan(&m.ID, &m.Name, &m.Address, &m.Reputation, &m.SalaryStatus, &m.ContactPhone, &m.Remark)
		m.Ships = getManagementShips(m.Name)
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
	err = db.QueryRow("SELECT id, name, address, reputation, salary_status, contact_phone, remark FROM management WHERE id = ?", id).
		Scan(&m.ID, &m.Name, &m.Address, &m.Reputation, &m.SalaryStatus, &m.ContactPhone, &m.Remark)

	if err == sql.ErrNoRows {
		sendError(w, http.StatusNotFound, "管理公司不存在")
		return
	}
	if err != nil {
		sendError(w, http.StatusInternalServerError, "查询失败: "+err.Error())
		return
	}
	m.Ships = getManagementShips(m.Name)
	sendSuccess(w, m)
}

func createManagement(w http.ResponseWriter, r *http.Request) {
	var m Management
	if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
		sendError(w, http.StatusBadRequest, "无效的请求数据")
		return
	}

	result, err := db.Exec(`INSERT INTO management (name, address, reputation, salary_status, contact_phone, remark) VALUES (?, ?, ?, ?, ?, ?)`,
		m.Name, m.Address, m.Reputation, m.SalaryStatus, m.ContactPhone, m.Remark)

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

	_, err = db.Exec(`UPDATE management SET name=?, address=?, reputation=?, salary_status=?, contact_phone=?, remark=? WHERE id=?`,
		m.Name, m.Address, m.Reputation, m.SalaryStatus, m.ContactPhone, m.Remark, id)

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
	query := "SELECT id, name, address, reputation, salary_status, contact_phone, remark FROM management"
	searchFields := []string{"name", "address", "reputation", "salary_status", "contact_phone", "remark"}

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
		rows.Scan(&m.ID, &m.Name, &m.Address, &m.Reputation, &m.SalaryStatus, &m.ContactPhone, &m.Remark)
		m.Ships = getManagementShips(m.Name)
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

	query := "SELECT id, name, address, reputation, salary_status, contact_phone, remark FROM management"
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
		rows.Scan(&m.ID, &m.Name, &m.Address, &m.Reputation, &m.SalaryStatus, &m.ContactPhone, &m.Remark)
		m.Ships = getManagementShips(m.Name)
		managements = append(managements, m)
	}
	sendSuccess(w, managements)
}
