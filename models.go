package main

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/gorilla/mux"
)

// 船员模型
type Crew struct {
	ID                 int    `json:"id"`
	Name               string `json:"name"`
	Region             string `json:"region"`
	BirthDate          string `json:"birth_date"`
	Education          string `json:"education"`
	GraduationSchool   string `json:"graduation_school"`
	Status             string `json:"status"`
	Position           string `json:"position"`
	CurrentShip        string `json:"current_ship"`
	Phone              string `json:"phone"`
	Height             int    `json:"height"`
	Weight             int    `json:"weight"`
	Experience         string `json:"experience"`
	IsProfessional     bool   `json:"is_professional"`
	ColleagueEvaluation string `json:"colleague_evaluation"`
	CompanyEvaluation  string `json:"company_evaluation"`
	Remark             string `json:"remark"`
}

// 船舶模型
type Ship struct {
	ID                int    `json:"id"`
	Name              string `json:"name"`
	BuildDate         string `json:"build_date"`
	ShipClass         string `json:"ship_class"`
	OwnerCompany      string `json:"owner_company"`
	CrewCompany       string `json:"crew_company"`
	EngineModel       string `json:"engine_model"`
	Power             string `json:"power"`
	GrossTonnage      string `json:"gross_tonnage"`
	DeadweightTonnage string `json:"deadweight_tonnage"`
	PortOfRegistry    string `json:"port_of_registry"`
	ShipCondition     string `json:"ship_condition"`
	SalaryStatus      string `json:"salary_status"`
	LivingExpense     string `json:"living_expense"`
	HasPension        bool   `json:"has_pension"`
	CanOpenSeal       bool   `json:"can_open_seal"`
	PersonnelPhone    string `json:"personnel_phone"`
	CompanyType       string `json:"company_type"`
	Remark            string `json:"remark"`
}

// 学校模型
type School struct {
	ID             int    `json:"id"`
	Name           string `json:"name"`
	Address        string `json:"address"`
	AdmissionPhone string `json:"admission_phone"`
	Level          string `json:"level"`
	OtherInfo      string `json:"other_info"`
}

// 船公司模型
type Company struct {
	ID           int      `json:"id"`
	Name         string   `json:"name"`
	Address      string   `json:"address"`
	ContactPhone string   `json:"contact_phone"`
	Remark       string   `json:"remark"`
	Ships        []string `json:"ships,omitempty"` // 拥有的船舶列表（通过查询ship表获取）
}

// 管理公司模型
type Management struct {
	ID           int      `json:"id"`
	Name         string   `json:"name"`
	Address      string   `json:"address"`
	Reputation   string   `json:"reputation"`
	SalaryStatus string   `json:"salary_status"`
	ContactPhone string   `json:"contact_phone"`
	Remark       string   `json:"remark"`
	Ships        []string `json:"ships,omitempty"` // 管理的船舶列表（通过查询ship表获取）
}

// 通用响应结构
type Response struct {
	Success bool        `json:"success"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

// 发送JSON响应
func sendJSON(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(data)
}

// 发送成功响应
func sendSuccess(w http.ResponseWriter, data interface{}) {
	sendJSON(w, http.StatusOK, Response{Success: true, Data: data})
}

// 发送错误响应
func sendError(w http.ResponseWriter, statusCode int, message string) {
	sendJSON(w, statusCode, Response{Success: false, Message: message})
}

// 解析ID参数
func parseID(r *http.Request) (int, error) {
	vars := mux.Vars(r)
	id, err := strconv.Atoi(vars["id"])
	return id, err
}

// 构建搜索查询（通用函数）
func buildSearchQuery(baseQuery, keyword string, searchFields []string) (string, []interface{}) {
	if keyword == "" {
		return baseQuery, []interface{}{}
	}

	var conditions []string
	var args []interface{}

	for _, field := range searchFields {
		conditions = append(conditions, field+" LIKE ?")
		args = append(args, "%"+keyword+"%")
	}

	whereClause := " WHERE " + strings.Join(conditions, " OR ")
	return baseQuery + whereClause, args
}

// 构建筛选查询（通用函数）
func buildFilterQuery(baseQuery string, filters map[string]interface{}) (string, []interface{}) {
	if len(filters) == 0 {
		return baseQuery, []interface{}{}
	}

	var conditions []string
	var args []interface{}

	for field, value := range filters {
		if value == nil {
			continue
		}

		// 处理范围查询（_min, _max）
		if strings.HasSuffix(field, "_min") {
			fieldName := strings.TrimSuffix(field, "_min")
			if strValue, ok := value.(string); ok && strValue != "" {
				conditions = append(conditions, fieldName+" >= ?")
				args = append(args, strValue)
			}
		} else if strings.HasSuffix(field, "_max") {
			fieldName := strings.TrimSuffix(field, "_max")
			if strValue, ok := value.(string); ok && strValue != "" {
				conditions = append(conditions, fieldName+" <= ?")
				args = append(args, strValue)
			}
		} else {
			// 普通LIKE查询
			if strValue, ok := value.(string); ok && strValue != "" {
				conditions = append(conditions, field+" LIKE ?")
				args = append(args, "%"+strValue+"%")
			}
		}
	}

	if len(conditions) == 0 {
		return baseQuery, []interface{}{}
	}

	whereClause := " WHERE " + strings.Join(conditions, " AND ")
	return baseQuery + whereClause, args
}
