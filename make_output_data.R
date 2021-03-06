
############### Sparkline data ---------------------
get_range(start='2020-03-15 01:00:00',
                 end=paste(period_end, "23:00:00")) %>%
  as_tibble() %>%
  na.omit() %>%
  filter(sa2_type != "Unclassified") %>%
  ## Scale values so the same y-axis wont squish everything
  group_by(sa2_type) %>%
  mutate(pop_scaled = as.numeric(scale(pop))) %>%
  select(-pop) %>%
  write_csv(paste0("outputs/report_", TIMESTAMP, "/sparkline_data.csv"))

############### Week plots ---------------------
latest_weeks <- get_range(start=paste(period_start, "01:00:00"),
                          end=paste(period_end, "23:00:00")) %>%
  as_tibble() %>%
  na.omit() %>%
  filter(sa2_type != "Unclassified") %>%
  mutate(week = isoweek(timestamp),
         day = wday(timestamp, label=TRUE, week_start = getOption("lubridate.week.start", eow)),
         day_num = wday(timestamp, week_start = getOption("lubridate.week.start", eow)),
         hour = hour(timestamp) + (day_num*24),
         
  ) %>%
  mutate(
    min_week = min(week),
    measure = ifelse(as.Date(timestamp) %in% unique(as.Date(timestamp))[1:(length(unique(as.Date(timestamp)))/2)],
           "baseline_week",
           "target_week")
    ) %>%
  select(sa2_type, timestamp, measure, day, hour, pop)

ref_year <- get_range(start=paste(period_start - days(365 + 7), "01:00:00"),
                      end=paste(period_end - days(365 - 7), "23:00:00")) %>%
  as_tibble() %>%
  na.omit() %>%
  filter(sa2_type != "Unclassified") %>%
  mutate(day = wday(timestamp, label=TRUE, week_start = getOption("lubridate.week.start", eow)),
         day_num = wday(timestamp, week_start = getOption("lubridate.week.start", eow)),
         hour = hour(timestamp) + (day_num*24)
  ) %>%
  group_by(sa2_type, day, hour) %>%
  summarise(pop = mean(pop)) %>%
  ungroup() %>%
  mutate(measure = "baseline_year",
         timestamp = NA
         ) %>%
  select(sa2_type, timestamp, measure, day, hour, pop)

bind_rows(latest_weeks,
          ref_year) %>%
  group_by(sa2_type) %>%
  mutate(pop_scaled = as.numeric(scale(pop, center=FALSE))) %>%
  select(-pop) %>%
  ungroup() %>%
  write_csv(paste0("outputs/report_", TIMESTAMP, "/week_comparison_data.csv"))

rm(ref_year, latest_weeks)

############### Mobility plots ---------------------

## Categories
mobility_baseline_categories <- get_mobility(conc = "sa2_type") %>%
  as_tibble() %>%
  filter(year(days) == 2019) %>%
  mutate(dow = wday(days, label=TRUE, week_start = getOption("lubridate.week.start", 1))) %>%
  group_by(sa2_type, dow) %>%
  summarise(minmax_baseline = mean(minmax))

get_mobility(conc = "sa2_type", period = '2020-01-01') %>%
  as_tibble() %>%
  filter(days > as.Date("2020-03-01") & sa2_type != "Unclassified") %>%
  mutate(dow = wday(days, label=TRUE, week_start = getOption("lubridate.week.start", 1))) %>%
  left_join(mobility_baseline_categories, by=c("sa2_type", "dow")) %>%
  mutate(mobility = (minmax - minmax_baseline) / minmax_baseline * 100) %>%
  select(days, sa2_type, mobility) %>%
  write_csv(paste0("outputs/report_", TIMESTAMP, "/mobility_category_data.csv"))

## Councils
mobility_baseline_councils <- get_mobility(conc = "council") %>%
  as_tibble() %>%
  filter(year(days) == 2019) %>%
  mutate(dow = wday(days, label=TRUE, week_start = getOption("lubridate.week.start", 1))) %>%
  group_by(regc2018_name, dow) %>%
  summarise(minmax_baseline = mean(minmax))

get_mobility(conc = "council", period = '2020-01-01') %>%
  as_tibble() %>%
  filter(days > as.Date("2020-03-01")) %>%
  mutate(dow = wday(days, label=TRUE, week_start = getOption("lubridate.week.start", 1))) %>%
  left_join(mobility_baseline_councils, by=c("regc2018_name", "dow")) %>%
  mutate(mobility = (minmax - minmax_baseline) / minmax_baseline * 100) %>%
  select(days, regc2018_name, mobility) %>%
  write_csv(paste0("outputs/report_", TIMESTAMP, "/mobility_council_data.csv"))

############### Weekly dot plots ---------------------
weekly_mobility_by_week <- get_mobility("councils") %>%
  as_tibble() %>%
  filter(between(days, period_start, period_end)) %>%
  mutate(measure = ifelse(days %in% unique(days)[1:(length(unique(days))/2)],
                          "baseline_week",
                          "target_week")) %>%
  group_by(regc2018_name, measure) %>%
  summarise(minmax = mean(minmax)) %>%
  spread(measure, minmax) %>%
  mutate(mobility = round((target_week - baseline_week) / baseline_week * 100, 1),
         comparison = "previous_week") %>%
  select(comparison, regc2018_name, mobility)

weekly_mobility_by_year <- get_mobility("councils") %>%
  as_tibble() %>%
  mutate(measure = case_when(
    between(days, period_start - days(365 + 7), period_end - days(365 - 7)) ~ "baseline_week",
    between(days, period_end - days(as.integer((epoch) / 2)), period_end) ~ "target_week"
  )) %>%
  filter(!(is.na(measure))) %>%
  group_by(regc2018_name, measure) %>%
  summarise(minmax = mean(minmax)) %>%
  spread(measure, minmax) %>%
  mutate(mobility = round((target_week - baseline_week) / baseline_week * 100, 1),
         comparison = "previous_year") %>%
  select(comparison, regc2018_name, mobility)
         
bind_rows(
  weekly_mobility_by_week,
  weekly_mobility_by_year
) %>%
  ungroup() %>%
  mutate(regc2018_name = factor(regc2018_name, levels=c("Northland Region",
                                                       "Auckland Region",
                                                       "Waikato Region",
                                                       "Bay of Plenty Region",
                                                       "Gisborne Region",
                                                       "Hawke's Bay Region",
                                                       "Taranaki Region",
                                                       "Manawatu-Wanganui Region",
                                                       "Wellington Region",
                                                       "West Coast Region",
                                                       "Canterbury Region",
                                                       "Otago Region",
                                                       "Southland Region",
                                                       "Tasman Region",
                                                       "Nelson Region",
                                                       "Marlborough Region")
                                )
         ) %>%
  arrange(comparison, regc2018_name) %>%
  write_csv(paste0("outputs/report_", TIMESTAMP, "/mobility_weekly_data.csv"))
