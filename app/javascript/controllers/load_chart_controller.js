import { Controller } from '@hotwired/stimulus'
import Chart from 'chart.js/auto'

// Connects to data-controller="load-chart"
export default class extends Controller {

  static values = {
    labels: Array,
    datasets: Array,
    type: { type: String, default: 'line' },
    title: String,
    indexAxis: { type: String, default: 'x' },
    legend: { type: Boolean, default: false }
  }

  connect () {

    const labels = this.labelsValue
    const datasets = this.datasetsValue

    const context = this.element.getContext('2d')

    this.chart = new Chart(context, {
      type: this.typeValue,
      data: {
        labels: labels,
        datasets: datasets
      },
      options: {
        indexAxis: this.indexAxisValue,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          colors: {enabled: true},
          title: {
            display: this.hasTitleValue,
            text: this.titleValue
          },
          legend: {
            display: this.legendValue,
            position: 'top',
            labels: {
              usePointStyle: true,
              boxWidth: 8,
              padding: 16
            }
          },
          tooltip: {
            backgroundColor: 'rgba(33, 33, 33, 0.92)',
            padding: 10,
            titleFont: { weight: '600' },
            bodySpacing: 4,
            cornerRadius: 6,
            usePointStyle: true
          }
        },
        responsive: true,
        scales: {
          x: this.#scales('x'),
          y: this.#scales('y')
        },
      }
    })

  }

  disconnect () {
    this.chart.destroy()
    this.chart = null
  }

  #scales (axe) {
    if (this.indexAxisValue === axe) {
      return {
        border: { display: false },
        grid: { display: false },
        ticks: {
          beginAtZero: false,
          maxRotation: 0,
          autoSkipPadding: 16,
          color: '#6c757d'
        }
      }
    } else {
      return {
        border: { display: false },
        grid: {
          color: 'rgba(0, 0, 0, 0.06)',
          drawTicks: false
        },
        ticks: {
          color: '#6c757d',
          padding: 8,
          maxTicksLimit: 6
        },
        beginAtZero: true
      }
    }
  }
}
