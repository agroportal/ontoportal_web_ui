  import { Controller } from "@hotwired/stimulus"
  import DataTable from 'datatables.net-dt'

  // Connects to data-controller="table-component"
  export default class extends Controller {
    static values = {
      sortcolumn: String,
      paging: Boolean,
      pageLength: Number,
      showAll: Boolean,
      allLabel: { type: String, default: 'All' },
      searching: Boolean,
      noinitsort: Boolean,
      searchPlaceholder: { type: String, default: 'Search' },
      serverSide: Boolean,
      ordering: Boolean,
      ajaxUrl: String,
      columns: Array
    }

    connect() {
      const table = this.element.querySelector('table')
      const defaultSortColumn = this.sortcolumnValue ? parseInt(this.sortcolumnValue, 10) : null
      const hasDefaultSort = Number.isFinite(defaultSortColumn)

      if (this.sortcolumnValue || this.searchingValue || this.pagingValue || this.serverSideValue) {
      
        const customLength = this.pageLengthValue > 0 ? this.pageLengthValue : null
        const baseLengths = customLength ? [customLength, 25, 50, 100] : [10, 25, 50, 100]
        const lengthValues = [...new Set(baseLengths)].sort((a, b) => a - b)
        if (this.showAllValue) lengthValues.push(-1)
        const lengthLabels = lengthValues.map(v => v === -1 ? this.allLabelValue : v)

        const config = {
          paging: this.pagingValue,
          ...(customLength && { pageLength: customLength }),
          ...(this.columnsValue?.length > 0 && { columns: this.columnsValue.map(name => ({ data: name })) }),
          info: false,
          lengthMenu: [lengthValues, lengthLabels],
          ordering: this.orderingValue,
          searching: this.searchingValue,
          autoWidth: true,
          order: this.noinitsortValue || !hasDefaultSort ? [] : [[defaultSortColumn, 'desc']],
          search: {
            return: true
          },
          language: {
            search: '_INPUT_',
            searchPlaceholder: this.searchPlaceholderValue
          }
        }

        if (this.serverSideValue) {
          config.serverSide = true
          config.processing = true
          config.rowId = 'id'
          config.ajax = {
            url: this.ajaxUrlValue,
            data: function (d) {
              return {
                page: Math.floor(d.start / d.length) + 1,
                pagesize: d.length,
                search: d.search.value
              }
            },
            dataSrc: function (json) {
              return json.collection || []
            }
          }
        }

        this.table = new DataTable(`#${table.id}`, config)

        DataTable.ext.errMode = 'none';
      
      }
      const searchInput = document.querySelector(`#${table.id}_filter input`)

      if (searchInput) {
        let lastSearchValue = ''
      
        searchInput.addEventListener('input', () => {
          const value = searchInput.value
          // Check if the input value has changed and is at least 3 characters long
          if ((value.length >= 3) || (value.length === 0 && lastSearchValue.length !== 0)) {
            this.table.search(value).draw()
          }
        
          lastSearchValue = value
        })
      }

    }
  }
