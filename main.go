package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
)

var db *sql.DB

func main() {
	// 数据库连接配置
	dbUser := getEnv("DB_USER", "root")
	dbPassword := getEnv("DB_PASSWORD", "rootmysql")
	dbHost := getEnv("DB_HOST", "localhost")
	dbPort := getEnv("DB_PORT", "3306")
	dbName := getEnv("DB_NAME", "infoManage")

	// 连接数据库
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%s)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		dbUser, dbPassword, dbHost, dbPort, dbName)

	var err error
	db, err = sql.Open("mysql", dsn)
	if err != nil {
		log.Fatal("数据库连接失败:", err)
	}
	defer db.Close()

	// 测试数据库连接
	if err = db.Ping(); err != nil {
		log.Fatal("数据库连接测试失败:", err)
	}

	fmt.Println("数据库连接成功")

	// 初始化数据库表
	initTables()

	// 设置路由
	r := mux.NewRouter()

	// 静态文件服务（禁用缓存，确保开发时总是获取最新文件）
	staticFileServer := http.StripPrefix("/static/", http.FileServer(http.Dir("./static/")))
	r.PathPrefix("/static/").Handler(noCacheHandler(staticFileServer))

	// 主页
	r.HandleFunc("/", indexHandler).Methods("GET")

	// API路由
	api := r.PathPrefix("/api").Subrouter()

	// 关联数据API（用于下拉框）
	api.HandleFunc("/schools/names", getSchoolNames).Methods("GET")
	api.HandleFunc("/ships/names", getShipNames).Methods("GET")
	api.HandleFunc("/companies/names", getCompanyNames).Methods("GET")
	api.HandleFunc("/managements/names", getManagementNames).Methods("GET")

	// 船员相关API（注意：search路由必须在{id}路由之前）
	api.HandleFunc("/crew/search", searchCrew).Methods("GET")
	api.HandleFunc("/crew/filter", filterCrew).Methods("POST")
	api.HandleFunc("/crew", getCrewList).Methods("GET")
	api.HandleFunc("/crew", createCrew).Methods("POST")
	api.HandleFunc("/crew/{id}", getCrew).Methods("GET")
	api.HandleFunc("/crew/{id}", updateCrew).Methods("PUT")
	api.HandleFunc("/crew/{id}", deleteCrew).Methods("DELETE")

	// 船舶相关API
	api.HandleFunc("/ship/search", searchShip).Methods("GET")
	api.HandleFunc("/ship/filter", filterShip).Methods("POST")
	api.HandleFunc("/ship", getShipList).Methods("GET")
	api.HandleFunc("/ship", createShip).Methods("POST")
	api.HandleFunc("/ship/{id}", getShip).Methods("GET")
	api.HandleFunc("/ship/{id}", updateShip).Methods("PUT")
	api.HandleFunc("/ship/{id}", deleteShip).Methods("DELETE")

	// 学校相关API
	api.HandleFunc("/school/search", searchSchool).Methods("GET")
	api.HandleFunc("/school/filter", filterSchool).Methods("POST")
	api.HandleFunc("/school", getSchoolList).Methods("GET")
	api.HandleFunc("/school", createSchool).Methods("POST")
	api.HandleFunc("/school/{id}", getSchool).Methods("GET")
	api.HandleFunc("/school/{id}", updateSchool).Methods("PUT")
	api.HandleFunc("/school/{id}", deleteSchool).Methods("DELETE")

	// 船公司相关API
	api.HandleFunc("/company/search", searchCompany).Methods("GET")
	api.HandleFunc("/company/filter", filterCompany).Methods("POST")
	api.HandleFunc("/company", getCompanyList).Methods("GET")
	api.HandleFunc("/company", createCompany).Methods("POST")
	api.HandleFunc("/company/{id}", getCompany).Methods("GET")
	api.HandleFunc("/company/{id}", updateCompany).Methods("PUT")
	api.HandleFunc("/company/{id}", deleteCompany).Methods("DELETE")

	// 管理公司相关API
	api.HandleFunc("/management/search", searchManagement).Methods("GET")
	api.HandleFunc("/management/filter", filterManagement).Methods("POST")
	api.HandleFunc("/management", getManagementList).Methods("GET")
	api.HandleFunc("/management", createManagement).Methods("POST")
	api.HandleFunc("/management/{id}", getManagement).Methods("GET")
	api.HandleFunc("/management/{id}", updateManagement).Methods("PUT")
	api.HandleFunc("/management/{id}", deleteManagement).Methods("DELETE")

	port := getEnv("PORT", "9901")
	fmt.Printf("服务器启动在端口 %s\n", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// noCacheHandler 包装一个Handler，添加禁用缓存的响应头
func noCacheHandler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 设置禁用缓存的响应头
		w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
		w.Header().Set("Pragma", "no-cache")
		w.Header().Set("Expires", "0")
		// 调用下一个处理器
		next.ServeHTTP(w, r)
	})
}

func indexHandler(w http.ResponseWriter, r *http.Request) {
	// 主页也禁用缓存，确保HTML文件更新后能立即看到
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("Expires", "0")
	http.ServeFile(w, r, "./static/index.html")
}
