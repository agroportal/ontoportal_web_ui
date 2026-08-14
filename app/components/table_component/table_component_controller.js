  import { Controller } from "@hotwired/stimulus"
  import DataTable from 'datatables.net-dt'

  // Connects to data-controller="table-component"
  export default class extends Controller {
    static values = {
      sortcolumn: String,
      paging: Boolean,
      searching: Boolean,
      noinitsort: Boolean,
      searchPlaceholder: { type: String, default: 'Search' },
      serverSide: Boolean,
      ordering: Boolean,
      ajaxUrl: String,
      columns: Array,
      showAll: Boolean,
      search: String
    }

    connect() {
      const table = this.element.querySelector('table')
      const defaultSortColumn = parseInt(this.sortcolumnValue, 10)

      if (this.sortcolumnValue || this.searchingValue || this.pagingValue || this.serverSideValue) {
      
        this.table = new DataTable(`#${table.id}`, {
          paging: this.pagingValue,
          ...(this.columnsValue?.length > 0 && { columns: this.columnsValue.map(name => ({ data: name })) }),
          info: false,
          lengthMenu: this.showAllValue ? [
            [10, 25, 50, 100, -1],
            [10, 25, 50, 100, 'All']
          ] : [
            [10, 25, 50, 100],
            [10, 25, 50, 100]
          ],
          ordering: this.orderingValue,
          searching: this.searchingValue,
          autoWidth: true,
          rowId: 'id',
          serverSide: this.serverSideValue,
          processing: true,
          ajax: this.serverSideValue ? {
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
          } : null,
          order: this.noinitsortValue ? [] : [[defaultSortColumn, 'desc']],
          search: {
            return: true,
            // Primes the filter box so a deep link like /agents?search=inrae
            // lands pre-filtered. Server-side tables send it with the first
            // ajax call, so no extra request is made.
            search: this.searchValue
          },
          language: {
            search: '_INPUT_',
            searchPlaceholder: this.searchPlaceholderValue
          }
        })

        DataTable.ext.errMode = 'none';
      
      }
      const searchInput = document.querySelector(`#${table.id}_filter input`)

      if (searchInput) {
        // Seeded so that clearing a short pre-filled search still resets the table.
        let lastSearchValue = this.searchValue || ''

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
