use axum::{
    extract::Extension,
    routing::{get, post},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::{mysql::MySqlPool, FromRow};
use utoipa::{OpenApi, ToSchema};
use utoipa_swagger_ui::SwaggerUi;

#[derive(Serialize, Deserialize, FromRow, ToSchema)]
struct Item {
    id: i64,
    name: String,
}

#[derive(OpenApi)]
#[openapi(paths(get_items, create_item), components(schemas(Item)))]
struct ApiDoc;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    let pool = MySqlPool::connect("mysql://root:test@localhost:3306").await?;

    sqlx::query("CREATE DATABASE IF NOT EXISTS sahuagin;")
        .execute(&pool)
        .await?;

    let pool = MySqlPool::connect("mysql://root:test@localhost:3306/sahuagin").await?;

    sqlx::query(
        r#"
        CREATE TABLE IF NOT EXISTS items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(255)
        );
    "#,
    )
    .execute(&pool)
    .await?;

    let app = Router::new()
        .route("/items", get(get_items).post(create_item))
        .merge(SwaggerUi::new("/docs").url("/api-docs/openapi.json", ApiDoc::openapi()))
        .layer(Extension(pool));

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();

    Ok(())
}

#[utoipa::path(
    get,
    path = "/items",
    responses((status = 200, body = [Item]))
)]
async fn get_items(Extension(pool): Extension<MySqlPool>) -> Json<Vec<Item>> {
    let items = sqlx::query_as::<_, Item>("SELECT id, name FROM items")
        .fetch_all(&pool)
        .await
        .unwrap();
    Json(items)
}

#[utoipa::path(
    post,
    path = "/items",
    request_body = Item,
    responses((status = 201, body = Item))
)]
async fn create_item(
    Extension(pool): Extension<MySqlPool>,
    Json(payload): Json<Item>,
) -> Json<Item> {
    let result = sqlx::query("INSERT INTO items (name) VALUES (?)")
        .bind(&payload.name)
        .execute(&pool)
        .await
        .unwrap();

    Json(Item {
        id: result.last_insert_id() as i64,
        name: payload.name,
    })
}
