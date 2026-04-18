library(tidyverse)
library(cfbfastR)

# ========================= CONFIGURATION ====================================

seasons <- c(2018, 2019, 2021, 2022, 2023, 2024)
transfer_seasons <- c(2021, 2022, 2023, 2024)


# ========================= TRANSFER PORTAL ==================================

#transfer_raw <- bind_rows(lapply(transfer_seasons, cfbd_recruiting_transfer_portal))
#write.csv(transfer_raw, "cfbd_qb_transfers_raw.csv", row.names = FALSE)

transfer_raw <- read.csv("cfbd_qb_transfers_raw.csv")

qb_transfers <- transfer_raw %>%
  filter(position == "QB", !is.na(destination)) %>%
  select(
    first_name, last_name,
    origin       = origin,
    destination  = destination,
    season,
    eligibility,
    rating,
    stars
  )


# ========================= ROSTERS ==========================================

# roster_raw <- data.frame()
# for (y in seasons) {
#   temp <- cfbd_team_roster(year = y) %>%
#     mutate(season = y)
#   roster_raw <- rbind(roster_raw, temp)
# }
# write.csv(roster_raw %>% select(-recruit_ids), "cfbd_qb_rosters.csv", row.names = FALSE)

roster_raw <- read.csv("cfbd_qb_rosters.csv")

qb_experience <- roster_raw %>%
  group_by(athlete_id) %>%
  summarize(
    years_in_college = n_distinct(season),
    first_season = min(season),
    .groups = 'drop'
  )

roster_qb <- roster_raw %>%
  filter(position == "QB") %>%
  select(athlete_id, first_name, last_name, team, season,
         hometown_city = home_city, hometown_state = home_state)

origin_id_lookup <- roster_qb %>%
  group_by(first_name, last_name, team) %>%
  slice_max(season, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(first_name, last_name, origin = team, athlete_id)

qb_transfers <- qb_transfers %>%
  left_join(origin_id_lookup, by = c("first_name", "last_name", "origin")) %>%
  filter(!is.na(athlete_id))


# ========================= QB PASSING STATS =================================

#player_stats_raw <- bind_rows(lapply(seasons, cfbd_stats_season_player))
#write.csv(player_stats_raw, "cfbd_player_stats.csv", row.names = FALSE)

player_stats_raw <- read.csv("cfbd_player_stats.csv")

qb_stats <- player_stats_raw %>%
  filter(position == "QB") %>%
  mutate(athlete_id = as.numeric(athlete_id)) %>%
  select(athlete_id, season = year, team,
         passing_pct, passing_yds, passing_td, passing_int, passing_ypa,
         rushing_car, rushing_yds, rushing_td, rushing_ypc)

qb_pre_transfer_stats <- qb_transfers %>%
  select(athlete_id, origin, destination, transfer_season = season) %>%
  left_join(qb_stats, by = c("athlete_id", "origin" = "team")) %>%
  filter(season < transfer_season) %>%
  group_by(athlete_id, origin, destination, transfer_season) %>%
  summarise(
    pre_seasons      = n(),
    pre_pass_yds     = sum(passing_yds,  na.rm = TRUE),
    pre_pass_td      = sum(passing_td,   na.rm = TRUE),
    pre_pass_int     = sum(passing_int,  na.rm = TRUE),
    pre_rush_yds     = sum(rushing_yds,  na.rm = TRUE),
    pre_rush_td      = sum(rushing_td,   na.rm = TRUE),
    pre_avg_pct      = mean(passing_pct, na.rm = TRUE),
    pre_avg_ypa      = mean(passing_ypa, na.rm = TRUE),
    pre_avg_ypc      = mean(rushing_ypc, na.rm = TRUE),
    .groups = "drop"
  )

# post_transfer_ppa <- bind_rows(lapply(transfer_seasons, function(y) {
#   cfbd_metrics_ppa_players_season(year = y) %>%
#     mutate(season = y)
# }))
# 
# write.csv(post_transfer_ppa, "post_transfer_ppa_raw.csv")
post_transfer_ppa <- read.csv("post_transfer_ppa_raw.csv") %>%
  select(athlete_id, season, post_ppa = total_PPA_all)

# ========================= TEAM STYLE (SP+ RATINGS) =========================

# sp_raw <- bind_rows(lapply(seasons, cfbd_ratings_sp))
# write.csv(sp_raw, "cfbd_sp_ratings.csv", row.names = FALSE)

sp_raw <- read.csv("cfbd_sp_ratings.csv")

sp_clean <- sp_raw %>%
  select(
    season          = year,
    team,
    sp_rating       = rating,
    sp_ranking      = ranking,
    off_rating      = offense_rating,
    off_ranking     = offense_ranking,
    def_rating      = defense_rating,
    def_ranking     = defense_ranking,
    st_rating       = special_teams_rating
  )


# ========================= TEAM HAVOC / PASSING DOWNS =======================

# team_adv_raw <- data.frame()
# for (y in seasons) {
#   temp <- cfbd_stats_season_advanced(year = y) %>%
#     mutate(season = y)
#   team_adv_raw <- rbind(team_adv_raw, temp)
# }
# write.csv(team_adv_raw, "cfbd_team_adv_stats.csv", row.names = FALSE)

team_adv_raw <- read.csv("cfbd_team_adv_stats.csv")

team_style <- team_adv_raw %>%
  select(
    season,
    team,
    off_plays,
    off_drives,
    off_ppa,
    off_total_ppa,
    off_success_rate,
    off_explosiveness,
    off_power_success,
    off_stuff_rate,
    off_passing_plays_rate,
    off_passing_plays_ppa,
    off_rushing_plays_rate,
    off_rushing_plays_ppa
  )
team_profile <- team_style %>%
  left_join(sp_clean, by = c("season", "team"))

dest_team_context <- team_profile %>%
  select(
    team, 
    season, 
    dest_off_ppa = off_ppa, 
    dest_off_success_rate = off_success_rate,
    dest_sp_offense = off_rating
  )

# ========================= RECRUITING RATINGS ================================

# recruit_raw <- data.frame()
# for (y in seasons) {
#   temp <- cfbd_recruiting_player(year = y)
#   recruit_raw <- rbind(recruit_raw, temp)
# }
# write.csv(recruit_raw, "cfbd_qb_recruits.csv", row.names = FALSE)

recruit_raw <- read.csv("cfbd_qb_recruits.csv")

recruit_clean <- recruit_raw %>%
  filter(position == "QB") %>%
  select(
    athlete_id,
    recruit_year   = year,
    recruit_rating = rating,
    recruit_stars  = stars,
    recruit_rank   = ranking,
    committed_to   = committed_to
  )

# ========================= BUILD MASTER DATASET ==============================

all_qb_seasons <- roster_raw %>%
  filter(position == "QB") %>%
  left_join(qb_experience, by = "athlete_id") %>%
  mutate(relative_year = season - first_season + 1) %>%
  select(athlete_id, first_name, last_name, team, season, relative_year)

prior_year_stats <- qb_stats %>%
  mutate(join_season = season + 1) %>% 
  select(athlete_id, 
         join_season, 
         prev_pass_yds = passing_yds, 
         prev_pass_td  = passing_td,
         prev_avg_ppa  = passing_pct,
         prev_team = team)

model_data_wide <- all_qb_seasons %>%
  left_join(recruit_clean %>% select(athlete_id, recruit_rating), by = "athlete_id") %>%
  left_join(prior_year_stats, by = c("athlete_id", "season" = "join_season")) %>%
  left_join(dest_team_context, by = c("team" = "team", "season" = "season")) %>%
  left_join(post_transfer_ppa, by = c("athlete_id", "season")) %>%
  filter(!is.na(prev_pass_yds), !is.na(post_ppa))

model_ready <- model_data_wide %>%
  mutate(is_transfer = ifelse(team != prev_team, 1, 0)) %>%
  select(
    athlete_id,
    first_name,
    last_name,
    team,
    season,
    post_ppa, #Target
    years_in_college = relative_year, 
    prev_pass_yds,
    prev_pass_td,
    prev_avg_ppa,
    dest_off_ppa,
    dest_sp_offense,
    is_transfer
  )

write.csv(model_ready, "qb_transfer_master.csv")
