package com.dashmate.dashmate

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template

class DashMateSearchScreen(
    carContext: CarContext,
    private val initialText: String = "",
    private val hintText: String = "Search or type URL...",
    private val onSubmitted: (String) -> Unit,
) : Screen(carContext) {

    private var currentText: String = initialText

    override fun onGetTemplate(): Template {
        return SearchTemplate.Builder(object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(searchText: String) {
                currentText = searchText
            }

            override fun onSearchSubmitted(searchText: String) {
                screenManager.pop()
                onSubmitted(searchText)
            }
        })
            .setHeaderAction(Action.BACK)
            .setInitialSearchText(initialText)
            .setSearchHint(hintText.ifBlank { "Search or type URL..." })
            .setShowKeyboardByDefault(true)
            .build()
    }
}
