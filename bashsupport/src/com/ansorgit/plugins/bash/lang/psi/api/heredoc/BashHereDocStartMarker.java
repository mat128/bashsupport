/*
 * Copyright 2009 Joachim Ansorg, mail@ansorg-it.com
 * File: BashHereDocStartMarker.java, Class: BashHereDocStartMarker
 * Last modified: 2010-01-31
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

package com.ansorgit.plugins.bash.lang.psi.api.heredoc;

/**
 * User: jansorg
 * Date: Jan 29, 2010
 * Time: 7:02:44 PM
 */
public interface BashHereDocStartMarker extends BashHereDocMarker {
    /**
     * Returns whether this marker introduces a new heredoc which evaluates variables or not.
     *
     * @return True if the new heredoc evaluates variables.
     */
    boolean isEvaluatingVariables();
}
