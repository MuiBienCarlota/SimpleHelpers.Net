#region *   License     *
/*
    SimpleHelpers - ConfigManager   

    Copyright © 2013 Khalid Salomão

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without
    restriction, including without limitation the rights to use,
    copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following
    conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
    NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
    HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
    OTHER DEALINGS IN THE SOFTWARE. 

    License: http://www.opensource.org/licenses/mit-license.php
    Website: https://github.com/khalidsalomao/SimpleHelpers.Net
 */
#endregion

using System;
using System.Collections.Generic;
using System.Linq;

namespace $rootnamespace$.SimpleHelpers
{
    /// <summary>
    /// Simple configuration manager to get and set the values in the AppSettings section of the default configuration file.
    /// </summary>
    public class ConfigManager
    {
        private static System.Configuration.Configuration m_instance = null;
        private static object m_lock = new object ();

        protected static Func<System.Configuration.Configuration> LoadConfiguration;

        private static System.Configuration.Configuration GetConfig ()
        {
            if (m_instance == null)
            {
                lock (m_lock)
                {
                    if (m_instance == null)
                    {
                        if (LoadConfiguration == null)
                        {
                            // get process name
                            var name = System.Diagnostics.Process.GetCurrentProcess ().ProcessName;
                            // remove extension
                            int num = name.LastIndexOf ('.');
                            if (num > 0)
                            {
                                name = name.Substring (0, num);
                            }
                            // check name
                            if (name.Equals ("w3wp", StringComparison.OrdinalIgnoreCase) || name.Equals ("aspnet_wp", StringComparison.OrdinalIgnoreCase))
                            {   //is web app
                                LoadConfiguration = () => System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration ("~");
                            }
                            else
                            {   //is windows app
                                LoadConfiguration = () => System.Configuration.ConfigurationManager.OpenExeConfiguration (System.Configuration.ConfigurationUserLevel.None);
                            }
                        }
                        m_instance = LoadConfiguration ();
                    }
                }
            }
            return m_instance;
        }

        /// <summary>
        /// Gets or sets the add non existing keys.
        /// </summary>
        /// <value>The add non existing keys.</value>
        public static bool AddNonExistingKeys { get; set; }

        /// <summary>
        /// Gets the specified key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="defaultValue">The default value.</param>
        /// <returns></returns>
        public static T Get<T> (string key, T defaultValue = default(T))
        {
            var cfg = GetConfig ().AppSettings.Settings;
            var item = cfg[key];
            if (item != null)
            {
                return Converter (item.Value, defaultValue);
            }
            else if (AddNonExistingKeys)
            {
                Set (key, defaultValue);
            }
            return defaultValue;
        }

        /// <summary>
        /// Sets the specified key.
        /// </summary>
        /// <param name="key">The key.</param>
        /// <param name="value">The value.</param>
        public static void Set<T> (string key, T value)
        {
            var mgr = GetConfig ();
            var cfg = mgr.AppSettings.Settings;
            var item = cfg[key];
            if (item == null)
            {
                cfg.Add (key, value.ToString ());
            }
            else
            {
                item.Value = value.ToString ();
            }
            mgr.Save (System.Configuration.ConfigurationSaveMode.Modified);
        }

        /// <summary>
        /// Sets the specified values.
        /// </summary>
        /// <param name="values">The values.</param>
        public static void Set (IEnumerable<KeyValuePair<string, string>> values)
        {
            var mgr = GetConfig ();
            var cfg = mgr.AppSettings.Settings;
            foreach (var i in values)
            {
                var item = cfg[i.Key];
                if (item == null)
                {
                    cfg.Add (i.Key, i.Value);
                }
                else
                {
                    item.Value = i.Value;
                }
            }
            mgr.Save (System.Configuration.ConfigurationSaveMode.Modified);
        }

        /// <summary>
        /// Converters the specified input.
        /// </summary>
        /// <param name="input">The input.</param>
        /// <param name="defaultValue">The default value.</param>
        /// <returns></returns>
        public static T Converter<T> (object input, T defaultValue = default(T))
        {
            if (input != null)
            {
                try
                {
                    return (T)Convert.ChangeType (input, typeof (T));
                }
                catch
                {
                    // return default value in case of a failed convertion
                }
            }
            return defaultValue;
        }
    }
}