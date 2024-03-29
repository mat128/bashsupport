/*
 * Copyright 2010 Joachim Ansorg, mail@ansorg-it.com
 * File: BashFunctionVariantsProcessor.java, Class: BashFunctionVariantsProcessor
 * Last modified: 2010-07-12
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.ansorgit.plugins.bash.lang.psi.impl.command;

import com.ansorgit.plugins.bash.lang.psi.api.function.BashFunctionDef;
import com.ansorgit.plugins.bash.lang.psi.util.BashAbstractProcessor;
import com.google.common.collect.Lists;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.Key;
import com.intellij.psi.PsiElement;
import com.intellij.psi.ResolveState;

import java.util.List;

/**
 * Date: 12.04.2009
 * Time: 23:20:07
 *
 * @author Joachim Ansorg
 */
class BashFunctionVariantsProcessor extends BashAbstractProcessor {
    private static final Logger log = Logger.getInstance("#bash.BashFunctionScopeProcessor");
    private final List<BashFunctionDef> functionDefs = Lists.newArrayList();

    public BashFunctionVariantsProcessor() {
        super(true);
    }

    public boolean execute(PsiElement element, ResolveState resolveState) {
        //resetResult();

        log.debug("Looking at " + element);
        if (element instanceof BashFunctionDef) {
            final BashFunctionDef f = (BashFunctionDef) element;
            functionDefs.add(f);
        }

        return true;
    }

    public <T> T getHint(Key<T> tKey) {
        return null;
    }

    public List<BashFunctionDef> getFunctionDefs() {
        return functionDefs;
    }
}