import {Controller} from "@hotwired/stimulus"
import useAjax from "../../javascript/mixins/useAjax";
import debounce from 'debounce'

// Connects to data-controller="search-input"
export default class extends Controller {
    static targets = ["input", "dropDown", "actionLink", "template", "button", "loader"]
    static values = {
        items: Array,
        ajaxUrl: String,
        itemLinkBase: String,
        idKey: String,
        cache: {type: Boolean, default: true},
        selectedItem: Number,
        searchEndpoint: {type: String, default: '/search'},
        displayAll: Boolean,
        sections: Array
    }

    connect() {
        this.input = this.inputTarget
        this.dropDown = this.dropDownTarget
        this.actionLinks = this.actionLinkTargets
        this.items = this.itemsValue
        this.search = debounce(this.search.bind(this), 100);
    }

    search() {
        this.selectedItemValue = 0
        this.loaderTarget.classList.remove("d-none")
        this.buttonTarget.classList.add("d-none")
        this.searchInput()
    }

    searchInput() {
        this.#fetchItems()
    }

    prevent(event){
        event.preventDefault();
    }
    blur() {
        this.dropDown.style.display = "none";
        this.input.classList.remove("home-dropdown-active");
    }
    arrow_up(){
        if (this.selectedItemValue > 1){
            this.selectedItemValue--
            this.dropDownTarget.querySelectorAll('.search-content')[this.selectedItemValue-1].style.backgroundColor = "rgba(0, 0, 0, 0.03)";
            this.dropDownTarget.querySelectorAll('.search-content')[this.selectedItemValue].style.background = 'white'
        }
    }
    arrow_down(){
        if(this.selectedItemValue<this.dropDownTarget.querySelectorAll('.search-content').length){
            this.selectedItemValue++
        }
        this.dropDownTarget.querySelectorAll('.search-content')[this.selectedItemValue-1].style.backgroundColor = "rgba(0, 0, 0, 0.03)";
        if(this.selectedItemValue > 1){
            this.dropDownTarget.querySelectorAll('.search-content')[this.selectedItemValue-2].style.background = 'white'
        } 
    }
    enter_key(){
        if(this.inputTarget.value != ''){
            let results = this.dropDownTarget.querySelectorAll('.search-content')
            if(this.selectedItemValue === 0 || this.dropDownTarget.style.display === 'none'){
                // The first action link is the primary one. Addressing it by
                // target rather than by offset from the end keeps Enter working
                // however many action links a call site declares.
                this.actionLinks[0]?.click()
            } else {
                results[this.selectedItemValue-1].click()
            }
        }
    }
    #inputValue() {
        return this.input.value.trim()
    }

    #useCache() {
        return this.cacheValue
    }


    #fetchItems() {
        if (this.items.length !== 0 && this.#useCache()) {
            this.#renderLines()
        } else {
            useAjax({
                type: "GET",
                url: this.ajaxUrlValue + encodeURIComponent(this.#inputValue()),
                dataType: "json",
                success: (data) => {
                    this.items = data.map(x => { return {...x, link: (this.itemLinkBaseValue + x[this.idKeyValue])}} )
                    this.#renderLines()
                },
                error: () => {
                    console.log("error")
                    //TODO show errors
                }
            })
        }
    }

    #renderLines() {
        this.loaderTarget.classList.add("d-none")
        this.buttonTarget.classList.remove("d-none")
        const inputValue = this.#inputValue();
        let results_list = []
        if (inputValue.length > 0) {
            this.buttonTarget.href = `${this.searchEndpointValue}?q=${inputValue}`;
            this.actionLinks.forEach(action => {
                const content = action.querySelector('p')
                content.innerHTML = inputValue
                const currentURL = new URL(action.href, document.location)
                currentURL.searchParams.set(currentURL.searchParams.keys().next().value, inputValue)
                action.href = currentURL.pathname + currentURL.search
            })

            this.dropDown.innerHTML = ""
            let breaker = 0
            for (let i = 0; i < this.items.length; i++) {
                if (!this.displayAllValue && breaker === 4) {
                    break;
                }
                // Get the current item from the ontologies array
                const item = this.items[i];

                let text =  Object.values(item).reduce((acc, value) => acc + value, "")
                
                // Check if the item contains the substring
                if (!this.cacheValue || text.toLowerCase().includes(inputValue.toLowerCase())) {
                    results_list.push(item);
                    breaker = breaker + 1
                }
            }

            this.#renderResults(results_list)

            this.actionLinks.forEach(x => this.dropDown.appendChild(x))
            this.dropDown.style.display = "block";

            this.input.classList.add("home-dropdown-active");


        } else {
            this.dropDown.style.display = "none";
            this.input.classList.remove("home-dropdown-active");
        }

    }

    // Without sections this appends every row in order, exactly as before.
    // With sections, rows are bucketed by their `group` key and each non-empty
    // bucket gets a heading. Anything whose group is unknown keeps the flat
    // behaviour and is appended last, so a result can never go missing.
    #renderResults(items) {
        const sections = this.sectionsValue
        if (sections.length === 0) {
            items.forEach(item => this.dropDown.appendChild(this.#renderLine(item)))
            return
        }

        const known = new Set(sections.map(s => s.key))
        sections.forEach(section => {
            let rows = items.filter(item => item.group === section.key)
            if (rows.length === 0) return
            // Capped so a section that comes back long (the content search
            // returns up to 50 concepts) cannot bury the sections under it.
            if (section.limit > 0) rows = rows.slice(0, section.limit)
            this.dropDown.appendChild(this.#renderSectionHeading(section.label))
            rows.forEach(item => this.dropDown.appendChild(this.#renderLine(item)))
        })
        items.filter(item => !known.has(item.group))
             .forEach(item => this.dropDown.appendChild(this.#renderLine(item)))
    }

    #renderSectionHeading(label) {
        const heading = document.createElement('p')
        // Deliberately not .search-content: arrow-key navigation indexes that
        // class and must skip over headings.
        heading.className = 'search-section-heading'
        heading.textContent = label
        return heading
    }

    #renderLine(item) {
        const node = this.templateTarget.content.firstElementChild.cloneNode(true)
        const values = {}

        Object.entries(item).forEach(([key, value]) => {
            key = key.toString().toUpperCase()
            if (key === 'TYPE') {
                value = value ? value.toString().split('/').slice(-1) : ''
            } else if (key === 'ACRONYM') {
                value = value ? `(${value.toString()})` : ''
            } else if (key === 'IDENTIFIERS') {
                value = value ? `- ${value.toString()}` : ''
            }
            values[key] = (value === null || value === undefined) ? '' : value.toString()
        })

        const keys = Object.keys(values)
        if (keys.length === 0) return node

        // Placeholders are upper-case, so match case-sensitively: a case
        // insensitive pass also rewrites lower-case class names that happen to
        // end in a placeholder ("home-result-type" became "home-result-Class").
        // One combined pass, so a substituted value that itself contains a
        // placeholder word is not clobbered by the next replacement.
        const escaped = keys.map(k => k.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        const regex = new RegExp('\\b(' + escaped.join('|') + ')\\b', 'g')
        const substitute = (text) => text.replace(regex, (match) => values[match])

        const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT)
        while (walker.nextNode()) {
            walker.currentNode.nodeValue = substitute(walker.currentNode.nodeValue)
        }
        // Substituting into live nodes rather than into an HTML string keeps
        // API-supplied names (agent names are free text) inert.
        for (const element of [node, ...node.querySelectorAll('*')]) {
            for (const attribute of Array.from(element.attributes)) {
                const replaced = substitute(attribute.value)
                if (replaced !== attribute.value) element.setAttribute(attribute.name, replaced)
            }
        }

        return node
    }
}
