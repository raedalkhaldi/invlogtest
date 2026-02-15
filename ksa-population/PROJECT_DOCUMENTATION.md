# KSA Population Data Analysis - Student Project Documentation

## Project Title
**Saudi Arabia Population Data Analysis & Interactive Visualization Dashboard**

## Course Information
- **Project Type**: Data Analysis & Web Development
- **Technologies Used**: Python, HTML/CSS/JavaScript, Chart.js, Cloudflare Pages
- **Data Source**: General Authority for Statistics (GASTAT) via DataSaudi API

---

## 1. Project Overview

This project fetches real-time population data for the Kingdom of Saudi Arabia from the official GASTAT DataSaudi API and presents it as an interactive web dashboard. The dashboard visualizes population breakdowns by gender, nationality (Saudi vs Non-Saudi), province (administrative region), and age group.

### Objectives
- Fetch and process official KSA population data using Python
- Build an interactive data visualization dashboard
- Deploy the project as a static website on Cloudflare Pages
- Practice working with REST APIs, data processing, and frontend charting libraries

---

## 2. Steps Taken

### Step 1: Research & API Exploration
- Explored the DataSaudi API at `https://api.datasaudi.sa`
- Discovered available data cubes using the `/tesseract/cubes` endpoint
- Identified two relevant cubes:
  - `gastat_population_province_sex_nationality` - National totals (has 2024 data)
  - `gastat_detailed_population` - Province-level detail with age groups (has 2022 census data)
- Tested API endpoints to understand the JSON response structure
- Documented all available fields: Province, Sex, Nationality, Age Range, Year, Population

### Step 2: Data Fetching Script (`fetch_data.py`)
- Wrote a Python script using `urllib` (standard library, no external dependencies needed)
- The script calls two API endpoints:
  1. **National API**: Fetches 2024 population totals by gender and nationality (9 records)
  2. **Detailed API**: Fetches province-level data with age/nationality/gender breakdowns (1,091 records, paginated in batches of 500)
- Data is processed and aggregated into structured JSON:
  - National summary (total, Saudi/Non-Saudi, male/female)
  - Province breakdown (13 provinces with population by gender and nationality)
  - Age group breakdown (21 age ranges with gender and nationality splits)
- Output is saved as `static/data/population.json`

### Step 3: Frontend Development
- Created `static/index.html` as the main page structure
- Used **Chart.js** (loaded from CDN) for interactive charts
- Designed a dark-themed dashboard with responsive CSS Grid layout
- Built 8 interactive visualizations:
  1. **Gender Distribution** (Doughnut chart)
  2. **Nationality Distribution** (Doughnut chart)
  3. **Nationality by Gender** (Bar chart)
  4. **Population by Province** (Horizontal bar chart)
  5. **Saudi vs Non-Saudi by Province** (Stacked bar chart)
  6. **Gender by Province** (Grouped bar chart)
  7. **Population Pyramid** (Horizontal stacked bar - age by gender)
  8. **Age by Nationality** (Stacked bar chart)
- Added KPI summary cards showing key statistics
- Built a sortable data table for province-level details
- All charts have interactive tooltips showing exact values and percentages

### Step 4: Styling (`static/css/style.css`)
- Dark theme design (background: #0f172a, cards: #1e293b)
- Responsive grid layout using CSS Grid with `auto-fit`
- KPI cards with hover effects and color-coded values
- Mobile-friendly breakpoints for tablets and phones
- Loading spinner animation while data loads

### Step 5: Build Process (`build.py`)
- Created a build script that:
  1. Runs `fetch_data.py` to get fresh data from the API
  2. Creates a clean `dist/` output directory
  3. Copies all static files (HTML, CSS, JS, data) to `dist/`
- The `dist/` folder is the deployment-ready output

### Step 6: Cloudflare Pages Deployment
- Created `wrangler.toml` configuration file pointing to the `dist/` directory
- Deployment steps:
  1. Run `python3 build.py` to generate the `dist/` folder
  2. Push code to a GitHub repository
  3. Connect the repository to Cloudflare Pages
  4. Set build command: `python3 build.py`
  5. Set output directory: `dist`

### Step 7: Testing
- Tested locally using `python3 serve.py` (runs on port 8080)
- Verified all charts render correctly with real API data
- Tested responsive design on different screen sizes
- Confirmed data accuracy by cross-checking with API responses

---

## 3. Project Structure

```
ksa-population/
├── fetch_data.py          # Python script to fetch data from API
├── build.py               # Build script for deployment
├── serve.py               # Local development server
├── requirements.txt       # Python dependencies (minimal)
├── wrangler.toml          # Cloudflare Pages configuration
├── .gitignore             # Git ignore rules
├── PROJECT_DOCUMENTATION.md  # This file
├── static/                # Source files
│   ├── index.html         # Main HTML page
│   ├── css/
│   │   └── style.css      # Dashboard styles
│   ├── js/
│   │   └── charts.js      # Chart.js visualization code
│   └── data/
│       └── population.json # Fetched & processed data
└── dist/                  # Build output (auto-generated)
    ├── index.html
    ├── css/style.css
    ├── js/charts.js
    └── data/population.json
```

---

## 4. API Details

### API 1: National Population (2024)
```
GET https://api.datasaudi.sa/tesseract/data.jsonrecords
  ?cube=gastat_population_province_sex_nationality
  &locale=ar
  &drilldowns=Province,Sex,Year,Nationality
  &measures=Population
  &include=Year:2024
  &limit=100,0
```
**Returns**: 9 records with national totals broken down by:
- Gender: Male (ذكور), Female (إناث), Total (الإجمالي)
- Nationality: Saudi (سعودي), Non-Saudi (غير سعودي), Total (الإجمالي)

### API 2: Detailed Population by Province (2022 Census)
```
GET https://api.datasaudi.sa/tesseract/data.jsonrecords
  ?cube=gastat_detailed_population
  &locale=ar
  &drilldowns=Geography Province,Sex,Year,Nationality,Age Range
  &measures=Population
  &limit=500,{offset}
```
**Returns**: 1,091 records with breakdowns by:
- 13 Provinces (Riyadh, Makkah, Madinah, etc.)
- 21 Age Groups (0-4, 5-9, ..., 80+)
- Gender (Male, Female)
- Nationality (Saudi, Non-Saudi)

---

## 5. Key Findings from the Data

### National Statistics (2024)
- **Total Population**: 35,300,280
- **Saudi Citizens**: 19,635,258 (55.6%)
- **Non-Saudi Residents**: 15,665,022 (44.4%)
- **Male Population**: 21,916,172 (62.1%)
- **Female Population**: 13,384,108 (37.9%)

### Notable Observations
- Males significantly outnumber females, mainly due to the large male non-Saudi workforce
- Saudi gender balance is nearly equal (9.83M male vs 9.81M female)
- Non-Saudi population is heavily male-skewed (12.1M male vs 3.6M female)
- Riyadh and Makkah are the most populous provinces
- The working-age population (25-39) shows the highest non-Saudi concentration

---

## 6. How to Run Locally

```bash
# 1. Clone the project
git clone <repository-url>
cd ksa-population

# 2. Build (fetches fresh data from API)
python3 build.py

# 3. Start local server
python3 serve.py

# 4. Open browser
# Visit http://localhost:8080
```

---

## 7. How to Deploy to Cloudflare Pages

### Option A: Cloudflare Dashboard (Recommended for Students)
1. Push your code to GitHub
2. Go to https://dash.cloudflare.com → Workers & Pages → Create
3. Select "Pages" → Connect to Git
4. Choose your repository
5. Set build configuration:
   - **Build command**: `python3 build.py`
   - **Build output directory**: `dist`
6. Click "Save and Deploy"

### Option B: Wrangler CLI
```bash
# Install Wrangler
npm install -g wrangler

# Login to Cloudflare
wrangler login

# Build the site
python3 build.py

# Deploy
wrangler pages deploy dist --project-name ksa-population
```

---

## 8. Technologies & Libraries

| Technology | Purpose | Version |
|-----------|---------|---------|
| Python 3 | Data fetching & build script | 3.9+ |
| urllib | HTTP requests (stdlib) | Built-in |
| Chart.js | Interactive charts | 4.4.1 (CDN) |
| HTML5/CSS3 | Page structure & styling | - |
| JavaScript | Chart rendering & interactivity | ES6 |
| Cloudflare Pages | Static site hosting | - |

---

## 9. Challenges Faced

1. **API Data Availability**: The detailed province-level data is only available for 2022 (census year), while national totals have 2024 data. We clearly labeled both years on the dashboard.
2. **Pagination**: The detailed API returns 1,091 records but limits to 500 per request, so the script fetches data in multiple pages.
3. **Arabic Data Labels**: The API returns data in Arabic. We kept the Arabic labels for authenticity and added English translations in the charts.
4. **No External Python Dependencies**: We used `urllib` from Python's standard library instead of `requests` to minimize setup requirements.

---

## 10. Future Improvements

- Add year selector to compare population across different years
- Add a map visualization showing population density by province
- Include governorate-level breakdown (sub-province data)
- Add data export functionality (CSV download)
- Implement Arabic/English language toggle

---

## References

- DataSaudi API: https://datasaudi.sa
- General Authority for Statistics: https://www.stats.gov.sa
- Chart.js Documentation: https://www.chartjs.org/docs/
- Cloudflare Pages Documentation: https://developers.cloudflare.com/pages/
