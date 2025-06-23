library(cbsodataR)

check_file_exists_or_download <- function(db_id, db_path, columns) {
    if (file.exists(db_path)) {
        df <- read.csv(db_path)
    } else {
        df <- cbs_get_data(id = db_id, select = columns)
        write.csv(df, db_path)
    }
    df
}
