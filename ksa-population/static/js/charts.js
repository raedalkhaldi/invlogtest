/**
 * KSA Population Data Visualization
 * Interactive charts using Chart.js
 */

// Color palettes
const COLORS = {
    blue: '#38bdf8',
    green: '#4ade80',
    amber: '#fbbf24',
    rose: '#fb7185',
    purple: '#a78bfa',
    teal: '#2dd4bf',
    orange: '#fb923c',
    cyan: '#22d3ee',
    lime: '#a3e635',
    pink: '#f472b6',
    indigo: '#818cf8',
    emerald: '#34d399',
    sky: '#7dd3fc',
};

const PROVINCE_COLORS = [
    '#38bdf8', '#4ade80', '#fbbf24', '#fb7185', '#a78bfa',
    '#2dd4bf', '#fb923c', '#22d3ee', '#a3e635', '#f472b6',
    '#818cf8', '#34d399', '#7dd3fc'
];

// Chart.js global defaults
Chart.defaults.color = '#94a3b8';
Chart.defaults.borderColor = '#334155';
Chart.defaults.font.family = "'Segoe UI', sans-serif";

let populationData = null;
let chartInstances = {};

// Format large numbers
function formatNumber(num) {
    if (num >= 1000000) return (num / 1000000).toFixed(1) + 'M';
    if (num >= 1000) return (num / 1000).toFixed(0) + 'K';
    return num.toLocaleString();
}

function formatFullNumber(num) {
    return num.toLocaleString();
}

// Load data and initialize
async function init() {
    try {
        const resp = await fetch('/data/population.json');
        populationData = await resp.json();
        document.getElementById('loading').style.display = 'none';
        document.getElementById('dashboard').style.display = 'block';
        renderKPIs();
        renderAllCharts();
        renderTable();
    } catch (err) {
        document.getElementById('loading').innerHTML =
            '<p style="color:#fb7185;">Failed to load data. Please run fetch_data.py first.</p>';
        console.error(err);
    }
}

function renderKPIs() {
    const d = populationData.national;
    document.getElementById('kpi-total').textContent = formatNumber(d.total_population);
    document.getElementById('kpi-saudi').textContent = formatNumber(d.saudi.total);
    document.getElementById('kpi-nonsaudi').textContent = formatNumber(d.non_saudi.total);
    document.getElementById('kpi-male').textContent = formatNumber(d.by_gender.male);
    document.getElementById('kpi-female').textContent = formatNumber(d.by_gender.female);

    const ratio = ((d.non_saudi.total / d.total_population) * 100).toFixed(1);
    document.getElementById('kpi-ratio').textContent = ratio + '%';
}

function destroyChart(id) {
    if (chartInstances[id]) {
        chartInstances[id].destroy();
        delete chartInstances[id];
    }
}

function renderAllCharts() {
    renderGenderPieChart();
    renderNationalityPieChart();
    renderProvinceBarChart();
    renderAgeBarChart();
    renderProvinceSaudiNonSaudiChart();
    renderAgeGenderPyramid();
    renderProvinceGenderChart();
    renderNationalityGenderBreakdown();
}

// 1. Gender Distribution (Doughnut)
function renderGenderPieChart() {
    destroyChart('genderChart');
    const d = populationData.national;
    const ctx = document.getElementById('genderChart').getContext('2d');
    chartInstances['genderChart'] = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Male (ذكور)', 'Female (إناث)'],
            datasets: [{
                data: [d.by_gender.male, d.by_gender.female],
                backgroundColor: [COLORS.blue, COLORS.rose],
                borderColor: '#1e293b',
                borderWidth: 3,
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'bottom', labels: { padding: 20 } },
                tooltip: {
                    callbacks: {
                        label: (ctx) => {
                            const total = d.by_gender.male + d.by_gender.female;
                            const pct = ((ctx.raw / total) * 100).toFixed(1);
                            return `${ctx.label}: ${formatFullNumber(ctx.raw)} (${pct}%)`;
                        }
                    }
                }
            }
        }
    });
}

// 2. Nationality Distribution (Doughnut)
function renderNationalityPieChart() {
    destroyChart('nationalityChart');
    const d = populationData.national;
    const ctx = document.getElementById('nationalityChart').getContext('2d');
    chartInstances['nationalityChart'] = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: ['Saudi (سعودي)', 'Non-Saudi (غير سعودي)'],
            datasets: [{
                data: [d.saudi.total, d.non_saudi.total],
                backgroundColor: [COLORS.green, COLORS.amber],
                borderColor: '#1e293b',
                borderWidth: 3,
            }]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'bottom', labels: { padding: 20 } },
                tooltip: {
                    callbacks: {
                        label: (ctx) => {
                            const total = d.saudi.total + d.non_saudi.total;
                            const pct = ((ctx.raw / total) * 100).toFixed(1);
                            return `${ctx.label}: ${formatFullNumber(ctx.raw)} (${pct}%)`;
                        }
                    }
                }
            }
        }
    });
}

// 3. Population by Province (Horizontal Bar)
function renderProvinceBarChart() {
    destroyChart('provinceChart');
    const provinces = populationData.provinces;
    const labels = Object.keys(provinces);
    const values = labels.map(p => provinces[p].total);

    const ctx = document.getElementById('provinceChart').getContext('2d');
    chartInstances['provinceChart'] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Population',
                data: values,
                backgroundColor: PROVINCE_COLORS.slice(0, labels.length),
                borderRadius: 4,
            }]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `Population: ${formatFullNumber(ctx.raw)}`
                    }
                }
            },
            scales: {
                x: {
                    ticks: { callback: (v) => formatNumber(v) },
                    grid: { color: 'rgba(51,65,85,0.5)' }
                },
                y: {
                    grid: { display: false }
                }
            }
        }
    });
}

// 4. Age Distribution (Vertical Bar)
function renderAgeBarChart() {
    destroyChart('ageChart');
    const ages = populationData.age_groups;
    const labels = Object.keys(ages);
    const saudiData = labels.map(a => ages[a].saudi);
    const nonSaudiData = labels.map(a => ages[a].non_saudi);

    const ctx = document.getElementById('ageChart').getContext('2d');
    chartInstances['ageChart'] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Saudi (سعودي)',
                    data: saudiData,
                    backgroundColor: COLORS.green,
                    borderRadius: 3,
                },
                {
                    label: 'Non-Saudi (غير سعودي)',
                    data: nonSaudiData,
                    backgroundColor: COLORS.amber,
                    borderRadius: 3,
                }
            ]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'top' },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.dataset.label}: ${formatFullNumber(ctx.raw)}`
                    }
                }
            },
            scales: {
                x: { stacked: true, grid: { display: false } },
                y: {
                    stacked: true,
                    ticks: { callback: (v) => formatNumber(v) },
                    grid: { color: 'rgba(51,65,85,0.5)' }
                }
            }
        }
    });
}

// 5. Province Saudi vs Non-Saudi (Stacked Bar)
function renderProvinceSaudiNonSaudiChart() {
    destroyChart('provinceSaudiChart');
    const provinces = populationData.provinces;
    const labels = Object.keys(provinces);
    const saudiData = labels.map(p => provinces[p].saudi);
    const nonSaudiData = labels.map(p => provinces[p].non_saudi);

    const ctx = document.getElementById('provinceSaudiChart').getContext('2d');
    chartInstances['provinceSaudiChart'] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Saudi (سعودي)',
                    data: saudiData,
                    backgroundColor: COLORS.teal,
                    borderRadius: 2,
                },
                {
                    label: 'Non-Saudi (غير سعودي)',
                    data: nonSaudiData,
                    backgroundColor: COLORS.orange,
                    borderRadius: 2,
                }
            ]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'top' },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.dataset.label}: ${formatFullNumber(ctx.raw)}`
                    }
                }
            },
            scales: {
                x: { stacked: true, grid: { display: false }, ticks: { maxRotation: 45 } },
                y: {
                    stacked: true,
                    ticks: { callback: (v) => formatNumber(v) },
                    grid: { color: 'rgba(51,65,85,0.5)' }
                }
            }
        }
    });
}

// 6. Population Pyramid (Age by Gender)
function renderAgeGenderPyramid() {
    destroyChart('pyramidChart');
    const ages = populationData.age_groups;
    const labels = Object.keys(ages);
    const maleData = labels.map(a => -ages[a].male); // negative for left side
    const femaleData = labels.map(a => ages[a].female);

    const ctx = document.getElementById('pyramidChart').getContext('2d');
    chartInstances['pyramidChart'] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Male (ذكور)',
                    data: maleData,
                    backgroundColor: COLORS.blue,
                    borderRadius: 3,
                },
                {
                    label: 'Female (إناث)',
                    data: femaleData,
                    backgroundColor: COLORS.rose,
                    borderRadius: 3,
                }
            ]
        },
        options: {
            indexAxis: 'y',
            responsive: true,
            plugins: {
                legend: { position: 'top' },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.dataset.label}: ${formatFullNumber(Math.abs(ctx.raw))}`
                    }
                }
            },
            scales: {
                x: {
                    stacked: true,
                    ticks: { callback: (v) => formatNumber(Math.abs(v)) },
                    grid: { color: 'rgba(51,65,85,0.5)' }
                },
                y: {
                    stacked: true,
                    grid: { display: false }
                }
            }
        }
    });
}

// 7. Province Gender Comparison
function renderProvinceGenderChart() {
    destroyChart('provinceGenderChart');
    const provinces = populationData.provinces;
    const labels = Object.keys(provinces);
    const maleData = labels.map(p => provinces[p].male);
    const femaleData = labels.map(p => provinces[p].female);

    const ctx = document.getElementById('provinceGenderChart').getContext('2d');
    chartInstances['provinceGenderChart'] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [
                {
                    label: 'Male (ذكور)',
                    data: maleData,
                    backgroundColor: COLORS.blue,
                    borderRadius: 2,
                },
                {
                    label: 'Female (إناث)',
                    data: femaleData,
                    backgroundColor: COLORS.rose,
                    borderRadius: 2,
                }
            ]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'top' },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.dataset.label}: ${formatFullNumber(ctx.raw)}`
                    }
                }
            },
            scales: {
                x: { grid: { display: false }, ticks: { maxRotation: 45 } },
                y: {
                    ticks: { callback: (v) => formatNumber(v) },
                    grid: { color: 'rgba(51,65,85,0.5)' }
                }
            }
        }
    });
}

// 8. Nationality-Gender Breakdown (Stacked)
function renderNationalityGenderBreakdown() {
    destroyChart('natGenderChart');
    const d = populationData.national;
    const ctx = document.getElementById('natGenderChart').getContext('2d');
    chartInstances['natGenderChart'] = new Chart(ctx, {
        type: 'bar',
        data: {
            labels: ['Saudi (سعودي)', 'Non-Saudi (غير سعودي)'],
            datasets: [
                {
                    label: 'Male (ذكور)',
                    data: [d.saudi.male, d.non_saudi.male],
                    backgroundColor: COLORS.blue,
                    borderRadius: 4,
                },
                {
                    label: 'Female (إناث)',
                    data: [d.saudi.female, d.non_saudi.female],
                    backgroundColor: COLORS.rose,
                    borderRadius: 4,
                }
            ]
        },
        options: {
            responsive: true,
            plugins: {
                legend: { position: 'top' },
                tooltip: {
                    callbacks: {
                        label: (ctx) => `${ctx.dataset.label}: ${formatFullNumber(ctx.raw)}`
                    }
                }
            },
            scales: {
                x: { grid: { display: false } },
                y: {
                    ticks: { callback: (v) => formatNumber(v) },
                    grid: { color: 'rgba(51,65,85,0.5)' }
                }
            }
        }
    });
}

// Province data table
function renderTable() {
    const provinces = populationData.provinces;
    const tbody = document.getElementById('province-table-body');
    tbody.innerHTML = '';

    let rank = 1;
    for (const [name, data] of Object.entries(provinces)) {
        const saudiPct = ((data.saudi / data.total) * 100).toFixed(1);
        const maleRatio = ((data.male / data.total) * 100).toFixed(1);
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>${rank}</td>
            <td>${name}</td>
            <td>${formatFullNumber(data.total)}</td>
            <td>${formatFullNumber(data.male)}</td>
            <td>${formatFullNumber(data.female)}</td>
            <td>${formatFullNumber(data.saudi)}</td>
            <td>${formatFullNumber(data.non_saudi)}</td>
            <td>${saudiPct}%</td>
            <td>${maleRatio}%</td>
        `;
        tbody.appendChild(tr);
        rank++;
    }
}

// Sort table
let sortDirection = {};
function sortTable(colIndex) {
    const tbody = document.getElementById('province-table-body');
    const rows = Array.from(tbody.querySelectorAll('tr'));
    const dir = sortDirection[colIndex] === 'asc' ? 'desc' : 'asc';
    sortDirection[colIndex] = dir;

    rows.sort((a, b) => {
        let aVal = a.children[colIndex].textContent.replace(/[,%]/g, '');
        let bVal = b.children[colIndex].textContent.replace(/[,%]/g, '');
        if (!isNaN(aVal) && !isNaN(bVal)) {
            aVal = parseFloat(aVal);
            bVal = parseFloat(bVal);
        }
        if (dir === 'asc') return aVal > bVal ? 1 : -1;
        return aVal < bVal ? 1 : -1;
    });

    rows.forEach(r => tbody.appendChild(r));
}

// Initialize on page load
document.addEventListener('DOMContentLoaded', init);
