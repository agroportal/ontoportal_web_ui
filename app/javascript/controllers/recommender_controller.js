import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="recommender"
export default class extends Controller {
  static targets = ['button', 'input', 'result', 'maxset', 'empty', 'ontologieschoice']

  connect(){
    if(document.querySelector('input[name="highlighted_recommendation"]:checked') !== null){
      this.handleHighlightedChange()
    }  

    let ontologies_choice = this.ontologieschoiceTarget.childNodes[1].childNodes[1]
    if(!ontologies_choice.checked){
      this.togglesets()
    }
  }
  edit(event){
    this.#toggle(this.buttonTarget)
    this.#toggle(event.currentTarget)
    this.#toggle(this.inputTarget)
    this.#toggle(this.resultTarget)
  }
  togglesets(){
    this.#toggle(this.maxsetTarget)
    this.#toggle(this.emptyTarget)
  }

  handleHighlightedChange(){
    let recommandations_area = this.resultTarget
    let jsonString = document.querySelector('input[name="highlighted_recommendation"]:checked').value;
    let jsonArray = JSON.parse(jsonString);
    var words = recommandations_area.textContent.split(/\s+/);
    for (var i = 0; i < words.length; i++) {
        var word = words[i].replace(/[.,\/#!$%\^&\*;:{}=\-_`~()]/g, '').toLowerCase(); // Remove punctuation and convert to lowercase
        var foundItem = jsonArray.find(item => item.text.toLowerCase() === word);

        if (foundItem) {
          // Replace the word with <a> tag
          words[i] = '<a style="color:var(--primary-color) !important;" href="' + foundItem.link + '">' + words[i] + '</a>';
        }
      }
    recommandations_area.innerHTML = words.join(' ');
  }

  handleInput(event){
    var selectedInputChoice = document.querySelector('input[name="input_type"]:checked').value;
    if (selectedInputChoice === "2"){
      const textarea = event.currentTarget
      const value = textarea.value;
      const lastCharIsSpace = event.data === ' ';
      const formattedValue = lastCharIsSpace ? value.trim() + ', ' : value;
      textarea.value = formattedValue;
    }
  }

  #toggle(element){
    element.classList.toggle('d-none')
  }
}
